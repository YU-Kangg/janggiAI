import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Game } from '../server/game.js';
import { fileStorage } from '../server/storage.js';
import { createServer } from '../server/index.js';
import { once } from 'node:events';

const act = (game, action, data = {}) => game.act(action, { revision: game.revision, ...data });
function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'janggi-history-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const path = join(dir, 'game.json');
  return { path, storage: fileStorage(path) };
}

test('파일 저장으로 차림·착수·종료 복원, 무르기·새 대국 저장', async t => {
  const { storage } = fixture(t);
  const game = new Game({ storage });
  await act(game, 'reset', { setup: { cho: 'bnbn', han: 'bnnb' } });
  await act(game, 'move', { move: 'e2e2' });
  await act(game, 'move', { move: 'e9e9' });
  let restored = new Game({ storage });
  assert.equal(restored.snapshot().fen, game.snapshot().fen);
  assert.deepEqual(restored.setup, game.setup);
  assert.equal(restored.snapshot().outcome.over, true);
  await act(restored, 'undo');
  assert.equal(new Game({ storage }).moves.length, 1);
  await act(restored, 'reset');
  assert.equal(new Game({ storage }).moves.length, 0);
});

test('AI 응수 저장, AI 차례 복원 시 수동 재개, 저장 실패 시 착수 보존', async t => {
  const { storage } = fixture(t);
  let resolve;
  const game = new Game({ storage, recommendMove: () => new Promise(r => { resolve = r; }) });
  await act(game, 'reset', { mode: 'ai', humanSide: 'han' });
  const restored = new Game({ storage });
  assert.equal(restored.snapshot().ai.status, 'paused');
  assert.equal(restored.aiJob, null);
  const done = game.aiJob.done;
  resolve({ move: 'a4b4' });
  await done;
  assert.deepEqual(new Game({ storage }).moves, ['a4b4']);
  const before = game.snapshot();
  storage.save = () => { throw Error('disk full'); };
  await assert.rejects(act(game, 'move', { move: 'a7b7' }), /disk full/);
  assert.deepEqual(game.snapshot(), before);
});

test('선택한 AI 난이도는 서버 재시작 후 복원됨', async t => {
  const { storage } = fixture(t);
  const game = new Game({ storage });
  await act(game, 'reset', { mode: 'ai', humanSide: 'cho', aiLevel: 'strong' });
  const restored = new Game({ storage });
  assert.equal(restored.snapshot().aiLevel, 'strong');
});

test('손상·불법 기보는 덮어쓰지 않고 로딩 실패', async t => {
  const { path, storage } = fixture(t);
  writeFileSync(path, '{broken');
  assert.throws(() => new Game({ storage }));
  assert.equal(readFileSync(path, 'utf8'), '{broken');
  writeFileSync(path, 'null');
  assert.throws(() => new Game({ storage }), /기보 형식/);
  const game = new Game();
  storage.save({ ...game.snapshot(), version: 1, moves: ['a1a10'] });
  assert.throws(() => new Game({ storage }));
});

test('HTTP 복기는 초기·중간·최종 장면 조회만 수행하고 범위·revision 검증', async t => {
  const game = new Game();
  const initial = game.snapshot().fen;
  await act(game, 'move', { move: 'a4b4' });
  const middle = game.snapshot().fen;
  await act(game, 'move', { move: 'a7b7' });
  const before = game.snapshot();
  const server = createServer({ game });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const request = (ply, revision = game.revision) => fetch(`http://127.0.0.1:${server.address().port}/api/review`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ply, revision }),
  });
  for (const [ply, fen] of [[0, initial], [1, middle], [2, before.fen]]) {
    const response = await request(ply);
    assert.equal(response.status, 200);
    const view = await response.json();
    assert.equal(view.fen, fen);
    assert.deepEqual(view.legalMoves, []);
    assert.deepEqual(game.snapshot(), before);
  }
  for (const ply of [-1, 3, 0.5, '1']) assert.equal((await request(ply)).status, 400);
  assert.equal((await request(1, 0)).status, 409);
});

test('자유 분석 분기는 양쪽 합법 수를 진행하고 원본 기보를 변경하지 않음', async () => {
  const game = new Game();
  await act(game, 'move', { move: 'a4b4' });
  await act(game, 'move', { move: 'a7b7' });
  const before = game.snapshot();

  const start = await act(game, 'variation', { basePly: 1, moves: [] });
  assert.equal(start.turn, 'han');
  assert.ok(start.legalMoves.includes('a7b7'));
  assert.deepEqual(start.variation, { basePly: 1, moves: [] });

  const first = await act(game, 'variation', { basePly: 1, moves: ['a7b7'] });
  assert.equal(first.turn, 'cho');
  assert.ok(first.legalMoves.includes('i4h4'));
  const second = await act(game, 'variation', { basePly: 1, moves: ['a7b7', 'i4h4'] });
  assert.equal(second.turn, 'han');
  assert.equal(second.moves.length, 3);
  assert.deepEqual(game.snapshot(), before);

  await assert.rejects(act(game, 'variation', { basePly: 3, moves: [] }), /시작 수 번호/);
  await assert.rejects(act(game, 'variation', { basePly: 1, moves: ['a1a10'] }), /합법적이지 않은/);
  await assert.rejects(act(game, 'variation', { basePly: 1, moves: 'a7b7' }), /수순 형식/);
  assert.deepEqual(game.snapshot(), before);
});
