import { recommend } from './engine.js';
import { rulePosition, initialFen, defaultSetup } from './rules.js';

const fail = (message, status = 409) => Object.assign(new Error(message), { status });

export class Game {
  moves = [];
  revision = 0;
  state = null;
  setup = { ...defaultSetup };
  mode = 'practice';
  humanSide = 'cho';
  aiStatus = 'idle';
  aiError = null;
  aiJob = null;

  constructor({ recommendMove = recommend, storage = null } = {}) {
    this.recommendMove = recommendMove;
    this.storage = storage;
    const saved = storage?.load();
    if (saved) {
      if (saved.version !== 1 || saved.variant !== 'janggi' || !Array.isArray(saved.moves)
        || !['practice', 'ai'].includes(saved.mode) || !['cho', 'han'].includes(saved.humanSide)
        || !Number.isSafeInteger(saved.revision) || saved.revision < 0) throw new Error('저장된 기보 형식이 올바르지 않습니다.');
      this.state = rulePosition(saved.moves, initialFen(saved.setup));
      this.moves = [...saved.moves];
      this.setup = { ...saved.setup };
      this.mode = saved.mode;
      this.humanSide = saved.humanSide;
      this.revision = saved.revision + 1;
      if (this.mode === 'ai' && !this.state.outcome.over && this.state.turn !== this.humanSide) this.aiStatus = 'paused';
    }
  }

  persist(moves, setup = this.setup, mode = this.mode, humanSide = this.humanSide) {
    this.storage?.save({ version: 1, variant: 'janggi', moves, setup, mode, humanSide, revision: this.revision + 1 });
  }

  lastHumanMove() {
    const parity = this.humanSide === 'cho' ? 0 : 1;
    for (let i = this.moves.length - 1; i >= 0; i--) if (i % 2 === parity) return i;
    return -1;
  }

  snapshot() {
    this.state ??= rulePosition(this.moves, initialFen(this.setup));
    return {
      ...this.state, initialFen: initialFen(this.setup), setup: { ...this.setup }, moves: [...this.moves], revision: this.revision, variant: 'janggi',
      mode: this.mode, humanSide: this.humanSide,
      canUndo: this.mode === 'ai' ? this.lastHumanMove() >= 0 : this.moves.length > 0,
      ai: { status: this.aiStatus, error: this.aiError },
    };
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
    job.done = Promise.resolve().then(() => this.recommendMove(moves, fen, { signal: job.controller.signal }))
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

  async act(action, data) {
    if (data.revision !== this.revision) {
      throw Object.assign(new Error('다른 화면에서 기보가 변경되었습니다. 새로고침하세요.'), { status: 409 });
    }
    const state = this.snapshot();
    if (action === 'review') {
      if (!Number.isInteger(data.ply) || data.ply < 0 || data.ply > this.moves.length) throw fail('복기할 수 번호가 올바르지 않습니다.', 400);
      const moves = this.moves.slice(0, data.ply);
      return { ...state, ...rulePosition(moves, initialFen(this.setup)), moves, legalMoves: [], canUndo: false };
    }
    if (action === 'variation') {
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
      if (!Number.isInteger(data.ply) || data.ply < 1 || data.ply > this.moves.length) throw fail('분석할 실제 수 번호가 올바르지 않습니다.', 400);
      if (this.aiJob) throw fail('AI 응수가 끝난 뒤 복기 분석을 시작하세요.');
      const revision = this.revision;
      const moveIndex = data.ply - 1;
      const moves = this.moves.slice(0, moveIndex);
      const position = rulePosition(moves, initialFen(this.setup));
      const result = await this.recommendMove(moves, initialFen(this.setup));
      if (this.revision !== revision) throw fail('분석 중 대국 상태가 변경되었습니다. 다시 시도하세요.');
      if (!position.legalMoves.includes(result.move)) throw new Error('합법 수가 아닌 복기 추천을 받았습니다.');
      const playedMove = this.moves[moveIndex];
      const afterMoves = [...moves, playedMove];
      const afterPosition = rulePosition(afterMoves, initialFen(this.setup));
      const recommendedPosition = rulePosition([...moves, result.move], initialFen(this.setup));
      let afterResult = null;
      if (!afterPosition.outcome.over) {
        afterResult = await this.recommendMove(afterMoves, initialFen(this.setup));
        if (this.revision !== revision) throw fail('분석 중 대국 상태가 변경되었습니다. 다시 시도하세요.');
        if (!afterPosition.legalMoves.includes(afterResult.move)) throw new Error('엔진이 둘 수 없는 착수 후 추천 수를 반환했습니다.');
      }
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
      return {
        revision, ply: data.ply, side: position.turn, playedMove,
        recommendedMove: result.move, match: playedMove === result.move,
        beforeFen: position.fen, recommendedFen: recommendedPosition.fen,
        budgetMs: result.budgetMs, source: result.source,
        analysis: {
          before: result.analysis ?? null,
          after: afterResult?.analysis ?? null,
          rawLossCp, lossCp, lossReason,
          terminalOutcome: afterPosition.outcome.over ? afterPosition.outcome : null,
        },
      };
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
    if (state.outcome.over && (action === 'move' || action === 'recommend')) {
      throw Object.assign(new Error('종료된 대국입니다. 무르기 또는 새 대국을 시작하세요.'), { status: 409 });
    }
    if ((action === 'move' || action === 'recommend') && this.mode === 'ai' && state.turn !== this.humanSide) {
      throw fail('AI 차례입니다. 응수를 기다리거나 재개하세요.');
    }
    if (action === 'recommend') {
      const result = await this.recommendMove([...this.moves], initialFen(this.setup));
      if (!state.legalMoves.includes(result.move)) throw new Error('합법 수가 아닌 추천을 받았습니다.');
      return { ...result, revision: this.revision };
    }
    let nextMoves;
    let nextSetup = this.setup;
    let nextMode = this.mode;
    let nextSide = this.humanSide;
    if (action === 'move') {
      if (!state.legalMoves.includes(data.move)) {
        throw Object.assign(new Error('둘 수 없는 수입니다.'), { status: 400 });
      }
      nextMoves = [...this.moves, data.move];
    } else if (action === 'undo') {
      if (!state.canUndo) throw fail('되돌릴 내 착수가 없습니다.');
      nextMoves = this.mode === 'ai' ? this.moves.slice(0, this.lastHumanMove()) : this.moves.slice(0, -1);
    }
    else if (action === 'reset') {
      nextMoves = [];
      nextSetup = data.setup ?? this.setup;
      nextMode = data.mode ?? this.mode;
      nextSide = data.humanSide ?? this.humanSide;
      if (!['practice', 'ai'].includes(nextMode) || !['cho', 'han'].includes(nextSide)) throw fail('대국 방식 또는 진영이 올바르지 않습니다.', 400);
      initialFen(nextSetup);
    }
    else throw Object.assign(new Error('지원하지 않는 동작입니다.'), { status: 404 });
    // Commit only after the engine has successfully reconstructed the new board.
    const nextState = rulePosition(nextMoves, initialFen(nextSetup));
    this.persist(nextMoves, nextSetup, nextMode, nextSide);
    this.stopAi();
    this.moves = nextMoves;
    this.setup = { cho: nextSetup.cho, han: nextSetup.han };
    this.mode = nextMode;
    this.humanSide = nextSide;
    this.state = nextState;
    this.revision += 1;
    if (action !== 'undo') this.startAi();
    return this.snapshot();
  }
}
