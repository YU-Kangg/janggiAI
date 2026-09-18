import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Game } from '../server/game.js';
import { createServer } from '../server/index.js';

const act = (game, action, data = {}) => game.act(action, { revision: game.revision, ...data });

test('선택한 실제 수의 착수 전후 평가 손실을 계산하고 대국을 변경하지 않음', async () => {
  const calls = [];
  const results = [
    { move: 'a4b4', cho: 20 }, { move: 'a7b7', cho: 10 },
    { move: 'a7b7', cho: 10 }, { move: 'i4h4', cho: 15 },
  ];
  const game = new Game({ recommendMove: async (moves, fen) => {
    calls.push({ moves: [...moves], fen });
    const result = results[calls.length - 1];
    return { move: result.move, budgetMs: 300, source: 'test-engine', analysis: { evaluation: { unit: 'cp', cho: result.cho }, pv: [result.move] } };
  } });
  await act(game, 'move', { move: 'a4b4' });
  await act(game, 'move', { move: 'a7b7' });
  const before = game.snapshot();
  const first = await act(game, 'review-analysis', { ply: 1 });
  const second = await act(game, 'review-analysis', { ply: 2 });

  assert.equal(first.side, 'cho');
  assert.equal(first.playedMove, 'a4b4');
  assert.equal(first.recommendedMove, 'a4b4');
  assert.equal(first.beforeFen, before.initialFen);
  assert.notEqual(first.recommendedFen, first.beforeFen);
  assert.deepEqual(first.prediction.moves, ['a4b4']);
  assert.equal(first.prediction.fens.length, 2);
  assert.equal(first.match, true);
  assert.equal(first.classification.key, 'best');
  assert.equal(first.analysis.rawLossCp, 10);
  assert.equal(first.analysis.lossCp, 10);
  assert.equal(first.analysis.lossReason, null);
  assert.equal(first.analysis.before.evaluation.cho, 20);
  assert.equal(first.analysis.after.evaluation.cho, 10);
  assert.equal(second.side, 'han');
  assert.equal(second.playedMove, 'a7b7');
  assert.equal(second.recommendedMove, 'a7b7');
  assert.equal(second.analysis.rawLossCp, 5);
  assert.equal(second.analysis.lossCp, 5);
  assert.equal(second.classification.key, 'best');
  assert.deepEqual(calls.map(call => call.moves), [[], ['a4b4'], ['a4b4'], ['a4b4', 'a7b7']]);
  assert.equal(calls[0].fen, before.initialFen);
  assert.deepEqual(game.snapshot(), before);
});

test('짧은 탐색 오차로 착수 후 평가가 좋아지면 손실은 0으로 보정하고 원값은 보존', async () => {
  const game = new Game({ recommendMove: async moves => ({
    move: moves.length ? 'a7b7' : 'i4h4', budgetMs: 300, source: 'test-engine',
    analysis: { evaluation: { unit: 'cp', cho: moves.length ? 25 : 20 } },
  }) });
  await act(game, 'move', { move: 'a4b4' });
  const result = await act(game, 'review-analysis', { ply: 1 });
  assert.equal(result.analysis.rawLossCp, -5);
  assert.equal(result.analysis.lossCp, 0);
  assert.equal(result.analysis.lossReason, null);
  assert.equal(result.classification.key, 'excellent');
});

test('대국을 끝낸 수는 착수 후 엔진을 호출하지 않고 평가 손실 사유를 반환', async () => {
  const calls = [];
  const game = new Game({ recommendMove: async moves => {
    calls.push([...moves]);
    return { move: 'e9e9', budgetMs: 300, source: 'test-engine', analysis: { evaluation: { unit: 'cp', cho: 0 } } };
  } });
  await act(game, 'move', { move: 'e2e2' });
  await act(game, 'move', { move: 'e9e9' });
  const result = await act(game, 'review-analysis', { ply: 2 });
  assert.deepEqual(calls, [['e2e2']]);
  assert.equal(result.analysis.after, null);
  assert.equal(result.analysis.lossCp, null);
  assert.equal(result.analysis.lossReason, 'terminal');
  assert.equal(result.analysis.terminalOutcome.over, true);
});

test('복기 분석은 범위·revision·추천 합법성을 검증', async t => {
  const game = new Game({ recommendMove: async () => ({ move: 'a1a10' }) });
  await act(game, 'move', { move: 'a4b4' });
  for (const ply of [-1, 0, 2, 0.5, '1']) await assert.rejects(act(game, 'review-analysis', { ply }), /수 번호/);
  await assert.rejects(game.act('review-analysis', { revision: 0, ply: 1 }), /변경/);
  await assert.rejects(act(game, 'review-analysis', { ply: 1 }), /합법 수가 아닌/);

  const server = createServer({ game });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const response = await fetch(`http://127.0.0.1:${server.address().port}/api/review-analysis`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ revision: game.revision, ply: 2 }),
  });
  assert.equal(response.status, 400);
});

test('자동 AI 탐색 중에는 서버 복기 분석을 시작하지 않음', async () => {
  const game = new Game({ recommendMove: () => new Promise(() => {}) });
  await act(game, 'reset', { mode: 'ai', humanSide: 'cho' });
  await act(game, 'move', { move: 'a4b4' });
  await assert.rejects(act(game, 'review-analysis', { ply: 1 }), /AI 응수/);
  game.stopAi();
});

test('전체 기보 리뷰는 위치 평가를 재사용하며 백그라운드 진행률과 결과를 제공', async () => {
  const calls = [];
  const engineResults = [
    { move: 'a4b4', cho: 20 }, { move: 'a7b7', cho: 10 }, { move: 'i4h4', cho: 15 },
  ];
  const game = new Game({ recommendMove: async moves => {
    calls.push([...moves]);
    const item = engineResults[moves.length];
    return {
      move: item.move, budgetMs: 300, source: 'test-engine',
      analysis: { evaluation: { unit: 'cp', cho: item.cho }, pv: [item.move] },
    };
  } });
  await act(game, 'move', { move: 'a4b4' });
  await act(game, 'move', { move: 'a7b7' });
  const before = game.snapshot();

  const started = await act(game, 'review-start');
  assert.equal(started.status, 'running');
  assert.equal(started.total, 2);
  await game.fullReviewJob.done;
  const complete = await act(game, 'review-status', { jobId: started.jobId });
  assert.equal(complete.status, 'complete');
  assert.equal(complete.completed, 2);
  assert.equal(complete.results.length, 2);
  assert.equal(complete.summary.total, 2);
  assert.equal(Object.values(complete.summary.counts).reduce((sum, count) => sum + count, 0), 2);
  assert.equal(complete.summary.averageLossCp, 8);
  assert.deepEqual(complete.results.map(item => item.analysis.lossCp), [10, 5]);
  assert.deepEqual(calls, [[], ['a4b4'], ['a4b4', 'a7b7']]);
  assert.deepEqual(game.snapshot(), before);

  const cached = await act(game, 'review-start');
  assert.equal(cached.status, 'complete');
  assert.equal(cached.jobId, started.jobId);
  assert.deepEqual(calls, [[], ['a4b4'], ['a4b4', 'a7b7']]);
});

test('전체 기보 리뷰는 취소할 수 있음', async () => {
  const game = new Game({ recommendMove: (_moves, _fen, { signal }) => new Promise((resolve, reject) => {
    if (signal.aborted) return reject(Object.assign(new Error('취소됨'), { name: 'AbortError' }));
    signal.addEventListener('abort', () => reject(Object.assign(new Error('취소됨'), { name: 'AbortError' })), { once: true });
  }) });
  await act(game, 'move', { move: 'a4b4' });
  const started = await act(game, 'review-start');
  await act(game, 'review-cancel');
  await game.fullReviewJob.done;
  const status = await act(game, 'review-status', { jobId: started.jobId });
  assert.equal(status.status, 'cancelled');
  assert.equal(status.completed, 0);
});
