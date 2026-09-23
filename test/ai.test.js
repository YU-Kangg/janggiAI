import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Game } from '../server/game.js';
import { createServer } from '../server/index.js';
import { runEngine } from '../server/engine.js';

const act = (game, action, data = {}) => game.act(action, { revision: game.revision, ...data });
function controlledGame() {
  const calls = [];
  const game = new Game({ recommendMove: (moves, fen, options) => new Promise((resolve, reject) => {
    calls.push({ moves, fen, signal: options?.signal, movetimeMs: options?.movetimeMs, resolve, reject });
  }) });
  return { game, calls };
}

test('초 선택: 내 착수 뒤 한 번만 자동 응수, AI 차례 조작 차단, 두 수 무르기', async () => {
  const { game, calls } = controlledGame();
  await act(game, 'reset', { mode: 'ai', humanSide: 'cho' });
  assert.equal(calls.length, 0);
  const thinking = await act(game, 'move', { move: 'a4b4' });
  assert.equal(thinking.ai.status, 'thinking');
  assert.equal(calls.length, 1);
  for (const action of ['move', 'recommend', 'resume-ai']) {
    await assert.rejects(act(game, action, { move: 'a7b7' }), /AI/);
  }
  const done = game.aiJob.done;
  calls[0].resolve({ move: 'a7b7' });
  await done;
  assert.deepEqual(game.moves, ['a4b4', 'a7b7']);
  assert.equal(game.snapshot().turn, 'cho');
  assert.equal(game.snapshot().ai.status, 'idle');
  await act(game, 'undo');
  assert.deepEqual(game.moves, []);
  assert.equal(calls.length, 1);
});

test('한 선택: AI 선착수, 내 착수 전에는 무르기 불가, 이후 한 차례로 복귀', async () => {
  const { game, calls } = controlledGame();
  const start = await act(game, 'reset', { mode: 'ai', humanSide: 'han' });
  assert.equal(start.ai.status, 'thinking');
  assert.equal(start.canUndo, false);
  let done = game.aiJob.done;
  calls[0].resolve({ move: 'a4b4' });
  await done;
  await assert.rejects(act(game, 'undo'), /되돌릴/);
  await act(game, 'move', { move: 'a7b7' });
  done = game.aiJob.done;
  calls[1].resolve({ move: 'i4h4' });
  await done;
  const undone = await act(game, 'undo');
  assert.deepEqual(undone.moves, ['a4b4']);
  assert.equal(undone.turn, 'han');
  assert.equal(undone.canUndo, false);
});

test('취소는 현재 판 유지, 재개 전까지 정지, 늦은 이전 결과를 폐기', async () => {
  const { game, calls } = controlledGame();
  await act(game, 'reset', { mode: 'ai', humanSide: 'cho' });
  await act(game, 'move', { move: 'a4b4' });
  const oldDone = game.aiJob.done;
  const paused = await act(game, 'cancel-ai');
  assert.deepEqual(paused.moves, ['a4b4']);
  assert.equal(paused.ai.status, 'paused');
  assert.equal(calls[0].signal.aborted, true);
  await act(game, 'resume-ai');
  const newDone = game.aiJob.done;
  calls[0].resolve({ move: 'a7b7' });
  await oldDone;
  assert.deepEqual(game.moves, ['a4b4']);
  assert.equal(game.aiStatus, 'thinking');
  calls[1].resolve({ move: 'i7h7' });
  await newDone;
  assert.deepEqual(game.moves, ['a4b4', 'i7h7']);
});

test('AI 난이도는 탐색 시간으로 전달되고 상태와 저장 기보에 유지됨', async () => {
  const { game, calls } = controlledGame();
  let state = await act(game, 'reset', { mode: 'ai', humanSide: 'cho', aiLevel: 'strong' });
  assert.equal(state.aiLevel, 'strong');
  await act(game, 'move', { move: 'a4b4' });
  assert.equal(calls[0].signal.aborted, false);
  assert.equal(calls[0].movetimeMs, 1000);
  const before = game.snapshot();
  await assert.rejects(act(game, 'reset', { aiLevel: 'impossible' }), /난이도/);
  assert.deepEqual(game.snapshot(), before);
  const done = game.aiJob.done;
  calls[0].resolve({ move: 'a7b7' });
  await done;
});

test('생각 중 무르기·새 대국은 이전 응수를 취소, 잘못된 설정은 상태를 보존', async () => {
  for (const action of ['undo', 'reset']) {
    const { game, calls } = controlledGame();
    await act(game, 'reset', { mode: 'ai', humanSide: 'cho' });
    await act(game, 'move', { move: 'a4b4' });
    const oldDone = game.aiJob.done;
    const before = game.snapshot();
    await assert.rejects(act(game, 'reset', { mode: 'invalid' }), /방식/);
    assert.deepEqual(game.snapshot(), before);
    await act(game, action, action === 'reset' ? { mode: 'practice' } : {});
    assert.equal(calls[0].signal.aborted, true);
    calls[0].resolve({ move: 'a7b7' });
    await oldDone;
    assert.deepEqual(game.moves, []);
    assert.equal(game.aiStatus, 'idle');
  }
});

test('AI 오류·불법 응수는 기보를 변경하지 않으며 재시도로 회복', async () => {
  for (const invalidMove of [false, true]) {
    const { game, calls } = controlledGame();
    await act(game, 'reset', { mode: 'ai', humanSide: 'han' });
    let done = game.aiJob.done;
    if (invalidMove) calls[0].resolve({ move: 'a1a10' });
    else calls[0].reject(new Error('시험용 엔진 오류'));
    await done;
    assert.equal(game.aiStatus, 'error');
    assert.deepEqual(game.moves, []);
    await act(game, 'resume-ai');
    done = game.aiJob.done;
    calls[1].resolve({ move: 'a4b4' });
    await done;
    assert.equal(game.aiStatus, 'idle');
    assert.deepEqual(game.moves, ['a4b4']);
  }
});

test('사람 착수 또는 AI 응수로 대국이 끝나면 추가 탐색하지 않음', async () => {
  const { game, calls } = controlledGame();
  await act(game, 'reset', { mode: 'ai', humanSide: 'han' });
  const done = game.aiJob.done;
  calls[0].resolve({ move: 'e2e2' });
  await done;
  const ended = await act(game, 'move', { move: 'e9e9' });
  assert.equal(ended.outcome.over, true);
  assert.equal(calls.length, 1);
  await assert.rejects(act(game, 'resume-ai'), /재개/);

  const second = controlledGame();
  await act(second.game, 'reset', { mode: 'ai', humanSide: 'cho' });
  await act(second.game, 'move', { move: 'e2e2' });
  const secondDone = second.game.aiJob.done;
  second.calls[0].resolve({ move: 'e9e9' });
  await secondDone;
  assert.equal(second.game.snapshot().outcome.over, true);
  assert.equal(second.game.aiStatus, 'idle');
});

test('HTTP: 긴 AI 탐색 중에도 상태 조회·취소 가능, 취소 이후 응수 미반영', async t => {
  const { game, calls } = controlledGame();
  const server = createServer({ game });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/api/`;
  const post = (path, data) => fetch(url + path, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data), signal: AbortSignal.timeout(3000),
  });
  let response = await post('reset', { revision: 0, mode: 'ai', humanSide: 'han' });
  assert.equal(response.status, 200);
  const thinking = await response.json();
  const done = game.aiJob.done;
  assert.equal(thinking.ai.status, 'thinking');
  const current = await (await fetch(url + 'game', { signal: AbortSignal.timeout(3000) })).json();
  assert.equal(current.ai.status, 'thinking');
  assert.equal(calls.length, 1);
  response = await post('cancel-ai', { revision: current.revision });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).ai.status, 'paused');
  calls[0].resolve({ move: 'a4b4' });
  await done;
  assert.deepEqual(game.moves, []);
});

test('실제 장기 NNUE: 초·한 선택 모두 자동 응수가 합법적', async () => {
  for (const humanSide of ['cho', 'han']) {
    const game = new Game();
    await act(game, 'reset', { mode: 'ai', humanSide });
    if (humanSide === 'cho') await act(game, 'move', { move: 'a4b4' });
    const legal = game.snapshot().legalMoves;
    await game.aiJob.done;
    assert.equal(game.aiStatus, 'idle');
    assert.ok(legal.includes(game.moves.at(-1)));
    assert.equal(game.snapshot().turn, humanSide);
  }
});

test('실제 엔진 탐색에 AbortSignal을 전달하면 취소됨', async () => {
  const controller = new AbortController();
  const search = runEngine([], true, undefined, { signal: controller.signal });
  controller.abort();
  await assert.rejects(search, { name: 'AbortError' });
  await assert.rejects(runEngine([], true, undefined, { signal: controller.signal }), { name: 'AbortError' });
});
