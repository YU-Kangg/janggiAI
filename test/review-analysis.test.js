import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Game } from '../server/game.js';
import { createServer } from '../server/index.js';

const act = (game, action, data = {}) => game.act(action, { revision: game.revision, ...data });

test('선택한 실제 수와 당시 서버 추천을 비교하고 대국은 변경하지 않음', async () => {
  const calls = [];
  const game = new Game({ recommendMove: async (moves, fen) => {
    calls.push({ moves: [...moves], fen });
    return { move: moves.length === 0 ? 'a4b4' : 'a7b7', budgetMs: 300, source: 'test-engine' };
  } });
  await act(game, 'move', { move: 'a4b4' });
  await act(game, 'move', { move: 'a7b7' });
  const before = game.snapshot();
  const first = await act(game, 'review-analysis', { ply: 1 });
  const second = await act(game, 'review-analysis', { ply: 2 });
  assert.deepEqual(first, {
    revision: 2, ply: 1, side: 'cho', playedMove: 'a4b4', recommendedMove: 'a4b4',
    match: true, budgetMs: 300, source: 'test-engine',
  });
  assert.equal(second.side, 'han');
  assert.equal(second.playedMove, 'a7b7');
  assert.equal(second.recommendedMove, 'a7b7');
  assert.deepEqual(calls.map(call => call.moves), [[], ['a4b4']]);
  assert.equal(calls[0].fen, before.initialFen);
  assert.deepEqual(game.snapshot(), before);
});

test('복기 분석은 범위·revision·추천 합법성을 검증', async t => {
  const game = new Game({ recommendMove: async () => ({ move: 'a1a10' }) });
  await act(game, 'move', { move: 'a4b4' });
  for (const ply of [-1, 0, 2, 0.5, '1']) await assert.rejects(act(game, 'review-analysis', { ply }), /수 번호/);
  await assert.rejects(game.act('review-analysis', { revision: 0, ply: 1 }), /변경/);
  await assert.rejects(act(game, 'review-analysis', { ply: 1 }), /합법 수/);

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
