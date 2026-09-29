import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Game } from '../server/game.js';
import { createServer } from '../server/index.js';
import { initialFen, rulePosition } from '../server/rules.js';

test('직접 둔 분기는 현재 위치와 직전 수를 평가하고 원본 대국을 보존', async t => {
  const game = new Game({ recommendMove: async (moves, fen) => {
    const move = rulePosition(moves, fen).legalMoves[0];
    return { move, source: 'test-engine', budgetMs: 300,
      analysis: { evaluation: { unit: 'cp', cho: moves.length * 70 }, pv: [move] } };
  } });
  const original = game.snapshot();
  const server = createServer({ game });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const post = data => fetch(`http://127.0.0.1:${server.address().port}/api/review-position`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
  });
  const response = await post({ initialFen: initialFen(), moves: ['a4b4', 'a7b7'], revision: 0 });
  assert.equal(response.status, 200);
  const value = await response.json();
  assert.equal(value.evaluation.cho, 140);
  assert.equal(value.entry.analysis.lossCp, 70);
  assert.equal(value.entry.classification.key, 'inaccuracy');
  assert.equal(value.entry.playedMove, 'a7b7');
  assert.deepEqual(value.moves, ['a4b4', 'a7b7']);
  assert.equal(value.fen, rulePosition(value.moves).fen);
  const terminal = await (await post({ initialFen: initialFen(), moves: ['e2e2', 'e9e9'], revision: 0 })).json();
  assert.equal(terminal.outcome.over, true);
  assert.equal(terminal.evaluation, null);
  assert.equal(terminal.entry.analysis.lossReason, 'terminal');
  for (const invalid of [{ moves: [] }, { initialFen: 'bad', moves: [] }, { initialFen: initialFen(), moves: ['a1a10'] }]) {
    assert.equal((await post(invalid)).status, 400);
  }
  assert.deepEqual(game.snapshot(), original);
});
