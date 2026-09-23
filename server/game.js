import { recommend } from './engine.js';
import { rulePosition, initialFen, defaultSetup } from './rules.js';

const fail = (message, status = 409) => Object.assign(new Error(message), { status });

export function classifyMove(match, lossCp) {
  if (match) return { key: 'best', label: '최선', experimental: true, basis: 'exact-match' };
  if (!Number.isFinite(lossCp)) return { key: 'unclassified', label: '분류 제외', experimental: true, basis: 'unavailable' };
  if (lossCp <= 15) return { key: 'excellent', label: '매우 좋음', experimental: true, basis: 'loss-cp' };
  if (lossCp <= 40) return { key: 'good', label: '좋음', experimental: true, basis: 'loss-cp' };
  if (lossCp <= 80) return { key: 'inaccuracy', label: '부정확', experimental: true, basis: 'loss-cp' };
  if (lossCp <= 160) return { key: 'mistake', label: '실수', experimental: true, basis: 'loss-cp' };
  return { key: 'blunder', label: '큰 실수', experimental: true, basis: 'loss-cp' };
}

export function summarizeReview(results) {
  const counts = { best: 0, excellent: 0, good: 0, inaccuracy: 0, mistake: 0, blunder: 0, unclassified: 0 };
  const sideStats = {
    cho: { total: 0, lossTotal: 0, lossCount: 0, keyMoves: 0 },
    han: { total: 0, lossTotal: 0, lossCount: 0, keyMoves: 0 },
  };
  let lossTotal = 0;
  let lossCount = 0;
  let depthTotal = 0;
  let depthCount = 0;
  let totalAnalysisMs = 0;
  let worstMove = null;
  for (const item of results) {
    const key = item.classification?.key ?? 'unclassified';
    counts[key] = (counts[key] ?? 0) + 1;
    const side = sideStats[item.side];
    if (side) {
      side.total++;
      if (['inaccuracy', 'mistake', 'blunder'].includes(key)) side.keyMoves++;
    }
    if (Number.isFinite(item.analysis?.lossCp)) {
      lossTotal += item.analysis.lossCp;
      lossCount++;
      if (side) {
        side.lossTotal += item.analysis.lossCp;
        side.lossCount++;
      }
      if (!worstMove || item.analysis.lossCp > worstMove.lossCp) {
        worstMove = { ply: item.ply, side: item.side, lossCp: item.analysis.lossCp };
      }
    }
    if (Number.isFinite(item.analysis?.before?.depth)) {
      depthTotal += item.analysis.before.depth;
      depthCount++;
    }
    for (const phase of ['before', 'after']) {
      if (Number.isFinite(item.analysis?.[phase]?.timeMs)) totalAnalysisMs += item.analysis[phase].timeMs;
    }
  }
  return {
    total: results.length, counts,
    keyMoves: counts.inaccuracy + counts.mistake + counts.blunder,
    comparableMoves: lossCount,
    bestMoveRate: results.length ? Math.round((counts.best / results.length) * 100) : null,
    averageDepth: depthCount ? Math.round(depthTotal / depthCount) : null,
    totalAnalysisMs,
    worstMove,
    averageLossCp: lossCount ? Math.round(lossTotal / lossCount) : null,
    bySide: Object.fromEntries(Object.entries(sideStats).map(([side, value]) => [side, {
      total: value.total,
      keyMoves: value.keyMoves,
      averageLossCp: value.lossCount ? Math.round(value.lossTotal / value.lossCount) : null,
    }])),
  };
}

function reviewEntry({ revision, ply, position, result, afterPosition, afterResult, playedMove }) {
  const beforeEvaluation = result.analysis?.evaluation;
  const afterEvaluation = afterResult?.analysis?.evaluation;
  let rawLossCp = null;
  let lossCp = null;
  let lossReason = null;
  if (afterPosition.outcome.over) lossReason = 'terminal';
  else if (!beforeEvaluation || !afterEvaluation) lossReason = 'analysis-unavailable';
  else if (beforeEvaluation.unit !== 'cp' || afterEvaluation.unit !== 'cp') lossReason = 'mate-score';
  else {
    const moverSign = position.turn === 'cho' ? 1 : -1;
    rawLossCp = moverSign * (beforeEvaluation.cho - afterEvaluation.cho);
    lossCp = Math.max(0, rawLossCp);
  }
  const recommendedPosition = rulePosition([...position.moves, result.move], position.initialFen);
  const predictionMoves = [];
  const predictionFens = [position.fen];
  let predictionHistory = [...position.moves];
  for (const move of result.analysis?.pv ?? []) {
    const current = rulePosition(predictionHistory, position.initialFen);
    if (current.outcome.over || !current.legalMoves.includes(move)) break;
    predictionHistory.push(move);
    predictionMoves.push(move);
    predictionFens.push(rulePosition(predictionHistory, position.initialFen).fen);
  }
  const match = playedMove === result.move;
  return {
    revision, ply, side: position.turn, playedMove,
    recommendedMove: result.move, match, classification: classifyMove(match, lossCp),
    beforeFen: position.fen, recommendedFen: recommendedPosition.fen,
    prediction: { moves: predictionMoves, fens: predictionFens },
    budgetMs: result.budgetMs, source: result.source,
    analysis: {
      before: result.analysis ?? null, after: afterResult?.analysis ?? null,
      rawLossCp, lossCp, lossReason,
      terminalOutcome: afterPosition.outcome.over ? afterPosition.outcome : null,
    },
  };
}

export class Game {
  moves = [];
  revision = 0;
  state = null;
  setup = { ...defaultSetup };
  mode = 'practice';
  humanSide = 'cho';
  aiLevel = 'normal';
  aiStatus = 'idle';
  aiError = null;
  aiJob = null;
  fullReviewJob = null;
  nextReviewJobId = 1;
  adjudication = null;
  timeControl = null;
  clockRemaining = { cho: 0, han: 0 };
  clockStartedAt = null;
  players = { cho: '초', han: '한' };

  constructor({ recommendMove = recommend, storage = null, now = () => Date.now() } = {}) {
    this.recommendMove = recommendMove;
    this.storage = storage;
    this.now = now;
    const saved = storage?.load();
    if (saved) {
      if (![1, 2, 3].includes(saved.version) || saved.variant !== 'janggi' || !Array.isArray(saved.moves)
        || !['practice', 'local', 'ai'].includes(saved.mode) || !['cho', 'han'].includes(saved.humanSide)
        || !Number.isSafeInteger(saved.revision) || saved.revision < 0) throw new Error('저장된 기보 형식이 올바르지 않습니다.');
      this.state = rulePosition(saved.moves, initialFen(saved.setup));
      this.moves = [...saved.moves];
      this.setup = { ...saved.setup };
      this.mode = saved.mode;
      this.humanSide = saved.humanSide;
      this.aiLevel = saved.version >= 3 ? saved.aiLevel ?? 'normal' : 'normal';
      if (!['quick', 'normal', 'strong'].includes(this.aiLevel)) throw new Error('저장된 AI 난이도가 올바르지 않습니다.');
      this.revision = saved.revision + 1;
      this.adjudication = saved.version >= 2 ? saved.adjudication ?? null : null;
      this.timeControl = saved.version >= 2 ? saved.timeControl ?? null : null;
      this.clockRemaining = saved.version >= 2 && saved.clockRemaining
        ? { cho: saved.clockRemaining.cho, han: saved.clockRemaining.han } : { cho: 0, han: 0 };
      this.clockStartedAt = this.timeControl && !this.adjudication && !this.state.outcome.over ? this.now() : null;
      this.players = saved.version >= 2 && saved.players ? { ...saved.players } : { cho: '초', han: '한' };
      if (this.mode === 'ai' && !this.state.outcome.over && this.state.turn !== this.humanSide) this.aiStatus = 'paused';
    }
  }

  persist(moves, setup = this.setup, mode = this.mode, humanSide = this.humanSide, adjudication = this.adjudication,
    timeControl = this.timeControl, clockRemaining = this.clockRemaining, players = this.players, aiLevel = this.aiLevel) {
    this.storage?.save({
      version: 3, variant: 'janggi', moves, setup, mode, humanSide, adjudication, aiLevel,
      timeControl, clockRemaining: { ...clockRemaining }, revision: this.revision + 1,
      players: { ...players },
    });
  }

  lastHumanMove() {
    const parity = this.humanSide === 'cho' ? 0 : 1;
    for (let i = this.moves.length - 1; i >= 0; i--) if (i % 2 === parity) return i;
    return -1;
  }

  snapshot() {
    this.state ??= rulePosition(this.moves, initialFen(this.setup));
    this.syncClock();
    const outcome = this.adjudication ?? this.state.outcome;
    return {
      ...this.state, outcome, initialFen: initialFen(this.setup), setup: { ...this.setup }, moves: [...this.moves], revision: this.revision, variant: 'janggi',
      mode: this.mode, humanSide: this.humanSide, aiLevel: this.aiLevel,
      players: { ...this.players },
      clock: {
        enabled: this.timeControl !== null,
        choMs: Math.max(0, Math.round(this.clockRemaining.cho)), hanMs: Math.max(0, Math.round(this.clockRemaining.han)),
        active: outcome.over || !this.timeControl ? null : this.state.turn,
        initialMs: this.timeControl?.initialMs ?? 0,
        incrementMs: this.timeControl?.incrementMs ?? 0,
      },
      canUndo: this.mode === 'ai' ? this.lastHumanMove() >= 0 : this.moves.length > 0,
      ai: { status: this.aiStatus, error: this.aiError },
    };
  }

  syncClock() {
    if (!this.timeControl || this.adjudication || !this.state || this.state.outcome.over || this.clockStartedAt == null) return;
    const current = this.state.turn;
    const currentTime = this.now();
    this.clockRemaining[current] -= Math.max(0, currentTime - this.clockStartedAt);
    this.clockStartedAt = currentTime;
    if (this.clockRemaining[current] <= 0) {
      this.clockRemaining[current] = 0;
      this.adjudication = {
        over: true, result: current === 'cho' ? '0-1' : '1-0',
        winner: current === 'cho' ? 'han' : 'cho', reason: '시간패',
      };
      this.clockStartedAt = null;
      this.persist(this.moves);
      this.revision++;
    }
  }

  clockConfiguration(value) {
    if (value == null) {
      return { timeControl: null, clockRemaining: { cho: 0, han: 0 } };
    }
    if (!Number.isInteger(value.initialSeconds) || value.initialSeconds < 10 || value.initialSeconds > 7200
      || !Number.isInteger(value.incrementSeconds) || value.incrementSeconds < 0 || value.incrementSeconds > 60) {
      throw fail('시간 설정이 올바르지 않습니다.', 400);
    }
    const timeControl = { initialMs: value.initialSeconds * 1000, incrementMs: value.incrementSeconds * 1000 };
    return { timeControl, clockRemaining: { cho: timeControl.initialMs, han: timeControl.initialMs } };
  }

  stopAi() {
    const job = this.aiJob;
    this.aiJob = null;
    job?.controller.abort();
    this.aiStatus = 'idle';
    this.aiError = null;
  }

  startAi() {
    const state = this.snapshot();
    if (this.mode !== 'ai' || state.outcome.over || state.turn === this.humanSide || this.aiJob) return;
    const job = { controller: new AbortController(), revision: this.revision };
    this.aiJob = job;
    this.aiStatus = 'thinking';
    this.aiError = null;
    const moves = [...this.moves];
    const fen = initialFen(this.setup);
    // Search outside the HTTP queue so cancel/undo/reset remain responsive.
    const movetimeMs = { quick: 100, normal: 300, strong: 1000 }[this.aiLevel];
    job.done = Promise.resolve().then(() => this.recommendMove(moves, fen, { signal: job.controller.signal, movetimeMs }))
      .then(result => {
        if (this.aiJob !== job || this.revision !== job.revision) return;
        if (!this.state.legalMoves.includes(result.move)) throw new Error('합법 수가 아닌 AI 응수를 받았습니다.');
        const nextMoves = [...this.moves, result.move];
        const nextState = rulePosition(nextMoves, fen);
        this.persist(nextMoves);
        this.moves = nextMoves;
        this.state = nextState;
        this.aiJob = null;
        this.aiStatus = 'idle';
        this.revision++;
      }).catch(error => {
        if (this.aiJob !== job || this.revision !== job.revision) return;
        this.aiJob = null;
        this.aiStatus = 'error';
        this.aiError = error.message;
        this.revision++;
      });
  }

  fullReviewSnapshot(job = this.fullReviewJob) {
    if (!job) return null;
    return {
      jobId: job.id, revision: job.revision, status: job.status,
      completed: job.completed, total: job.total, results: [...job.results],
      summary: summarizeReview(job.results), error: job.error,
    };
  }

  stopFullReview() {
    this.fullReviewJob?.controller.abort();
  }

  startFullReview() {
    if (this.fullReviewJob?.revision === this.revision && ['running', 'complete'].includes(this.fullReviewJob.status)) {
      return this.fullReviewSnapshot();
    }
    const job = {
      id: this.nextReviewJobId++, revision: this.revision, status: 'running', completed: 0,
      total: this.moves.length, results: [], error: null, controller: new AbortController(),
    };
    this.fullReviewJob = job;
    const gameMoves = [...this.moves];
    const startFen = initialFen(this.setup);
    job.done = Promise.resolve().then(async () => {
      let previousPosition = null;
      let previousResult = null;
      for (let index = 0; index <= gameMoves.length; index++) {
        if (this.revision !== job.revision || this.fullReviewJob !== job) throw Object.assign(new Error('대국 상태가 변경되어 전체 리뷰를 중단했습니다.'), { name: 'ReviewCancelled' });
        const prefix = gameMoves.slice(0, index);
        const position = { ...rulePosition(prefix, startFen), moves: prefix, initialFen: startFen };
        let result = null;
        if (!position.outcome.over) {
          result = await this.recommendMove(prefix, startFen, { signal: job.controller.signal });
          if (!position.legalMoves.includes(result.move)) throw new Error('합법 수가 아닌 전체 리뷰 추천을 받았습니다.');
        }
        if (index > 0) {
          job.results.push(reviewEntry({
            revision: job.revision, ply: index, position: previousPosition, result: previousResult,
            afterPosition: position, afterResult: result, playedMove: gameMoves[index - 1],
          }));
          job.completed = index;
        }
        previousPosition = position;
        previousResult = result;
      }
      job.status = 'complete';
    }).catch(error => {
      job.status = error.name === 'AbortError' || error.name === 'ReviewCancelled' ? 'cancelled' : 'error';
      job.error = error.message;
    });
    return this.fullReviewSnapshot(job);
  }

  async act(action, data) {
    const state = this.snapshot();
    if (data.revision !== this.revision) {
      throw Object.assign(new Error('다른 화면에서 기보가 변경되었습니다. 새로고침하세요.'), { status: 409 });
    }
    if (action === 'review') {
      if (this.mode === 'local' && !state.outcome.over) throw fail('로컬 대국이 끝난 뒤 복기할 수 있습니다.');
      if (!Number.isInteger(data.ply) || data.ply < 0 || data.ply > this.moves.length) throw fail('복기할 수 번호가 올바르지 않습니다.', 400);
      const moves = this.moves.slice(0, data.ply);
      return { ...state, ...rulePosition(moves, initialFen(this.setup)), moves, legalMoves: [], canUndo: false };
    }
    if (action === 'variation') {
      if (this.mode === 'local' && !state.outcome.over) throw fail('로컬 대국이 끝난 뒤 분석할 수 있습니다.');
      if (!Number.isInteger(data.basePly) || data.basePly < 0 || data.basePly > this.moves.length) throw fail('분기 시작 수 번호가 올바르지 않습니다.', 400);
      if (!Array.isArray(data.moves) || data.moves.length > 128 || data.moves.some(move => typeof move !== 'string')) {
        throw fail('분기 수순 형식이 올바르지 않습니다.', 400);
      }
      const baseMoves = this.moves.slice(0, data.basePly);
      const moves = [...baseMoves, ...data.moves];
      const position = rulePosition(moves, initialFen(this.setup));
      return {
        ...state, ...position, moves, revision: this.revision, legalMoves: position.legalMoves,
        canUndo: data.moves.length > 0, variation: { basePly: data.basePly, moves: [...data.moves] },
      };
    }
    if (action === 'review-analysis') {
      if (this.mode === 'local' && !state.outcome.over) throw fail('로컬 대국이 끝난 뒤 분석할 수 있습니다.');
      if (!Number.isInteger(data.ply) || data.ply < 1 || data.ply > this.moves.length) throw fail('분석할 실제 수 번호가 올바르지 않습니다.', 400);
      if (this.aiJob) throw fail('AI 응수가 끝난 뒤 복기 분석을 시작하세요.');
      const revision = this.revision;
      const moveIndex = data.ply - 1;
      const moves = this.moves.slice(0, moveIndex);
      const startFen = initialFen(this.setup);
      const position = { ...rulePosition(moves, startFen), moves, initialFen: startFen };
      const result = await this.recommendMove(moves, initialFen(this.setup));
      if (this.revision !== revision) throw fail('분석 중 대국 상태가 변경되었습니다. 다시 시도하세요.');
      if (!position.legalMoves.includes(result.move)) throw new Error('합법 수가 아닌 복기 추천을 받았습니다.');
      const playedMove = this.moves[moveIndex];
      const afterMoves = [...moves, playedMove];
      const afterPosition = rulePosition(afterMoves, startFen);
      let afterResult = null;
      if (!afterPosition.outcome.over) {
        afterResult = await this.recommendMove(afterMoves, initialFen(this.setup));
        if (this.revision !== revision) throw fail('분석 중 대국 상태가 변경되었습니다. 다시 시도하세요.');
        if (!afterPosition.legalMoves.includes(afterResult.move)) throw new Error('엔진이 둘 수 없는 착수 후 추천 수를 반환했습니다.');
      }
      return reviewEntry({ revision, ply: data.ply, position, result, afterPosition, afterResult, playedMove });
    }
    if (action === 'review-start') {
      if (this.mode === 'local' && !state.outcome.over) throw fail('로컬 대국이 끝난 뒤 리뷰할 수 있습니다.');
      if (!this.moves.length) throw fail('분석할 기보가 없습니다.', 400);
      if (this.aiJob) throw fail('AI 응수가 끝난 뒤 전체 리뷰를 시작하세요.');
      return this.startFullReview();
    }
    if (action === 'review-status') {
      if (!this.fullReviewJob || (data.jobId != null && data.jobId !== this.fullReviewJob.id)) throw fail('전체 리뷰 작업을 찾을 수 없습니다.', 404);
      return this.fullReviewSnapshot();
    }
    if (action === 'review-latest') {
      if (!this.fullReviewJob || this.fullReviewJob.revision !== this.revision
        || !['running', 'complete'].includes(this.fullReviewJob.status)) {
        return { revision: this.revision, status: 'none' };
      }
      return this.fullReviewSnapshot();
    }
    if (action === 'review-cancel') {
      if (!this.fullReviewJob || this.fullReviewJob.status !== 'running') throw fail('진행 중인 전체 리뷰가 없습니다.');
      this.fullReviewJob.controller.abort();
      return this.fullReviewSnapshot();
    }
    if (action === 'cancel-ai') {
      if (!this.aiJob) throw fail('진행 중인 AI 응수가 없습니다.');
      this.stopAi();
      this.aiStatus = 'paused';
      this.revision++;
      return this.snapshot();
    }
    if (action === 'resume-ai') {
      if (this.mode !== 'ai' || state.outcome.over || state.turn === this.humanSide || this.aiJob) {
        throw fail('AI 응수를 재개할 수 없는 상태입니다.');
      }
      this.revision++;
      this.startAi();
      return this.snapshot();
    }
    if (action === 'resign') {
      if (this.mode !== 'local') throw fail('로컬 대국에서만 기권할 수 있습니다.');
      if (state.outcome.over) throw fail('이미 종료된 대국입니다.');
      if (!['cho', 'han'].includes(data.side) || data.side !== state.turn) throw fail('현재 차례 진영만 기권할 수 있습니다.', 400);
      const adjudication = {
        over: true, result: data.side === 'cho' ? '0-1' : '1-0',
        winner: data.side === 'cho' ? 'han' : 'cho', reason: '기권',
      };
      this.persist(this.moves, this.setup, this.mode, this.humanSide, adjudication);
      this.stopAi();
      this.adjudication = adjudication;
      this.clockStartedAt = null;
      this.revision++;
      return this.snapshot();
    }
    if (action === 'draw') {
      if (this.mode !== 'local') throw fail('로컬 대국에서만 합의 무승부를 사용할 수 있습니다.');
      if (state.outcome.over) throw fail('이미 종료된 대국입니다.');
      const adjudication = { over: true, result: '1/2-1/2', winner: null, reason: '합의 무승부' };
      this.persist(this.moves, this.setup, this.mode, this.humanSide, adjudication);
      this.stopAi();
      this.adjudication = adjudication;
      this.clockStartedAt = null;
      this.revision++;
      return this.snapshot();
    }
    if (state.outcome.over && (action === 'move' || action === 'recommend')) {
      throw Object.assign(new Error('종료된 대국입니다. 무르기 또는 새 대국을 시작하세요.'), { status: 409 });
    }
    if ((action === 'move' || action === 'recommend') && this.mode === 'ai' && state.turn !== this.humanSide) {
      throw fail('AI 차례입니다. 응수를 기다리거나 재개하세요.');
    }
    if (action === 'recommend') {
      if (this.mode === 'local' && !state.outcome.over) throw fail('로컬 대국이 끝난 뒤 추천을 사용할 수 있습니다.');
      const result = await this.recommendMove([...this.moves], initialFen(this.setup));
      if (!state.legalMoves.includes(result.move)) throw new Error('합법 수가 아닌 추천을 받았습니다.');
      return { ...result, revision: this.revision };
    }
    let nextMoves;
    let nextSetup = this.setup;
    let nextMode = this.mode;
    let nextSide = this.humanSide;
    let nextAiLevel = this.aiLevel;
    let nextPlayers = this.players;
    let nextTimeControl = this.timeControl;
    let nextClockRemaining = { ...this.clockRemaining };
    if (action === 'move') {
      if (!state.legalMoves.includes(data.move)) {
        throw Object.assign(new Error('둘 수 없는 수입니다.'), { status: 400 });
      }
      nextMoves = [...this.moves, data.move];
      if (nextTimeControl) nextClockRemaining[state.turn] += nextTimeControl.incrementMs;
    } else if (action === 'undo') {
      if (!state.canUndo) throw fail('되돌릴 내 착수가 없습니다.');
      nextMoves = this.mode === 'ai' ? this.moves.slice(0, this.lastHumanMove()) : this.moves.slice(0, -1);
    }
    else if (action === 'reset') {
      nextMoves = [];
      nextSetup = data.setup ?? this.setup;
      nextMode = data.mode ?? this.mode;
      nextSide = data.humanSide ?? this.humanSide;
      nextAiLevel = data.aiLevel ?? this.aiLevel;
      nextPlayers = data.players ?? this.players;
      if (!['practice', 'local', 'ai'].includes(nextMode) || !['cho', 'han'].includes(nextSide)) throw fail('대국 방식 또는 진영이 올바르지 않습니다.', 400);
      if (!['quick', 'normal', 'strong'].includes(nextAiLevel)) throw fail('AI 난이도가 올바르지 않습니다.', 400);
      if (!nextPlayers || typeof nextPlayers.cho !== 'string' || typeof nextPlayers.han !== 'string'
        || !nextPlayers.cho.trim() || !nextPlayers.han.trim() || nextPlayers.cho.trim().length > 12 || nextPlayers.han.trim().length > 12) {
        throw fail('대국자 이름은 1~12자로 입력하세요.', 400);
      }
      nextPlayers = { cho: nextPlayers.cho.trim(), han: nextPlayers.han.trim() };
      initialFen(nextSetup);
      ({ timeControl: nextTimeControl, clockRemaining: nextClockRemaining } = this.clockConfiguration(data.timeControl ?? null));
    }
    else throw Object.assign(new Error('지원하지 않는 동작입니다.'), { status: 404 });
    // Commit only after the engine has successfully reconstructed the new board.
    const nextState = rulePosition(nextMoves, initialFen(nextSetup));
    this.persist(nextMoves, nextSetup, nextMode, nextSide, null, nextTimeControl, nextClockRemaining, nextPlayers, nextAiLevel);
    this.stopAi();
    this.moves = nextMoves;
    this.setup = { cho: nextSetup.cho, han: nextSetup.han };
    this.mode = nextMode;
    this.humanSide = nextSide;
    this.aiLevel = nextAiLevel;
    this.players = nextPlayers;
    this.state = nextState;
    this.adjudication = null;
    this.timeControl = nextTimeControl;
    this.clockRemaining = nextClockRemaining;
    this.clockStartedAt = this.timeControl ? this.now() : null;
    this.revision += 1;
    if (action !== 'undo') this.startAi();
    return this.snapshot();
  }
}
