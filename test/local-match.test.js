import test from 'node:test';
import assert from 'node:assert/strict';
import { Game } from '../server/game.js';

const act = (game, action, data = {}) => game.act(action, { revision: game.revision, ...data });
const quietEngine = async () => { throw new Error('로컬 대국에서 엔진을 호출하면 안 됩니다.'); };

test('로컬 대국은 양쪽 차림·무제한 시간을 적용하고 번갈아 착수한다', async () => {
  const game = new Game({ recommendMove: quietEngine });
  let state = await act(game, 'reset', {
    mode: 'local', setup: { cho: 'bnnb', han: 'nbnb' }, timeControl: null,
  });
  assert.equal(state.mode, 'local');
  assert.deepEqual(state.setup, { cho: 'bnnb', han: 'nbnb' });
  assert.equal(state.clock.enabled, false);
  const first = state.legalMoves.find(move => !move.endsWith(move.slice(0, move.length / 2)));
  state = await act(game, 'move', { move: first });
  assert.equal(state.moves.length, 1);
  assert.equal(state.turn, 'han');
  const second = state.legalMoves[0];
  state = await act(game, 'move', { move: second });
  assert.equal(state.moves.length, 2);
  assert.equal(state.turn, 'cho');
});

test('진행 중인 로컬 대국은 추천·복기·분석을 차단한다', async () => {
  const game = new Game({ recommendMove: quietEngine });
  await act(game, 'reset', { mode: 'local', timeControl: null });
  for (const [action, data] of [
    ['recommend', {}], ['review', { ply: 0 }], ['variation', { basePly: 0, moves: [] }],
    ['review-analysis', { ply: 1 }], ['review-start', {}],
  ]) await assert.rejects(act(game, action, data), /로컬 대국이 끝난 뒤|기보가 없습니다/);
});

test('로컬 기권·합의 무승부와 종료 뒤 무르기·재대국', async () => {
  const game = new Game({ recommendMove: quietEngine });
  let state = await act(game, 'reset', { mode: 'local', timeControl: null });
  const first = state.legalMoves[0];
  state = await act(game, 'move', { move: first });
  await assert.rejects(act(game, 'resign', { side: 'cho' }), /현재 차례/);
  state = await act(game, 'resign', { side: 'han' });
  assert.deepEqual(state.outcome, { over: true, result: '1-0', winner: 'cho', reason: '기권' });
  state = await act(game, 'undo');
  assert.equal(state.outcome.over, false);
  assert.equal(state.moves.length, 0);
  state = await act(game, 'draw');
  assert.equal(state.outcome.result, '1/2-1/2');
  assert.equal(state.outcome.reason, '합의 무승부');
  state = await act(game, 'reset', { mode: 'local', timeControl: null });
  assert.equal(state.outcome.over, false);
  assert.equal(state.moves.length, 0);
});

test('로컬 대국 시계는 착수 시간을 차감하고 증분을 더하며 시간패를 판정한다', async () => {
  let now = 1000;
  const game = new Game({ recommendMove: quietEngine, now: () => now });
  let state = await act(game, 'reset', {
    mode: 'local', timeControl: { initialSeconds: 10, incrementSeconds: 2 },
  });
  assert.equal(state.clock.choMs, 10000);
  now += 3000;
  state = game.snapshot();
  assert.equal(state.clock.choMs, 7000);
  const move = state.legalMoves[0];
  state = await act(game, 'move', { move });
  assert.equal(state.clock.choMs, 9000);
  assert.equal(state.clock.active, 'han');
  now += 10001;
  state = game.snapshot();
  assert.equal(state.outcome.over, true);
  assert.equal(state.outcome.winner, 'cho');
  assert.equal(state.outcome.reason, '시간패');
  assert.equal(state.clock.hanMs, 0);
});

test('로컬 종료와 시계는 저장 후 복원된다', async () => {
  let saved = null;
  const storage = { load: () => saved, save: value => { saved = structuredClone(value); } };
  let now = 0;
  const first = new Game({ recommendMove: quietEngine, storage, now: () => now });
  await act(first, 'reset', { mode: 'local', timeControl: { initialSeconds: 300, incrementSeconds: 0 } });
  now += 1500;
  first.snapshot();
  const ended = await act(first, 'draw');
  assert.equal(ended.outcome.reason, '합의 무승부');
  const restored = new Game({ recommendMove: quietEngine, storage, now: () => now });
  const state = restored.snapshot();
  assert.equal(state.mode, 'local');
  assert.equal(state.clock.enabled, true);
  assert.equal(state.clock.choMs, 298500);
  assert.equal(state.outcome.reason, '합의 무승부');
});
