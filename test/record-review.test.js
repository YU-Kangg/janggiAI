import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Game } from '../server/game.js';
import { createServer } from '../server/index.js';
import { defaultSetup, initialFen } from '../server/rules.js';

test('기기 기보를 별도 Stockfish 작업으로 분석하고 서버 대국은 보존', async t => {
  const calls = [];
  const game = new Game({ recommendMove: async moves => {
    calls.push([...moves]);
    await new Promise(resolve => setTimeout(resolve, 20));
    const move = ['i4h4', 'a7b7', 'i4h4'][moves.length];
    return { move, source: 'test-engine', budgetMs: 300,
      analysis: { evaluation: { unit: 'cp', cho: [100, 90, 160][moves.length] }, pv: [move] } };
  } });
  const before = game.snapshot();
  const server = createServer({ game });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const post = async (action, body) => fetch(`http://127.0.0.1:${server.address().port}/api/${action}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const data = { revision: 12, setup: defaultSetup, moves: ['a4b4', 'a7b7'] };
  for (const invalid of [{ ...data, moves: ['a1a10'] }, { ...data, setup: null }, { ...data, moves: [] }]) {
    assert.equal((await post('record-review-start', invalid)).status, 400);
  }
  const started = await post('record-review-start', data);
  assert.equal(started.status, 200);
  let job = await started.json();
  assert.equal(job.status, 'running');
  assert.equal(job.total, 2);
  assert.equal((await (await post('record-review-start', data)).json()).recordJobId, job.recordJobId);
  assert.equal((await post('record-review-start', { ...data, revision: 13 })).status, 409);
  assert.equal((await post('record-review-status', { recordJobId: 'wrong' })).status, 404);
  for (let i = 0; i < 100 && job.status === 'running'; i++) {
    await new Promise(resolve => setTimeout(resolve, 10));
    job = await (await post('record-review-status', { recordJobId: job.recordJobId })).json();
  }
  assert.equal(job.status, 'complete');
  assert.equal(job.completed, 2);
  assert.equal(job.revision, 12);
  assert.equal(job.summary.counts.excellent, 1);
  assert.equal(job.summary.counts.best, 1);
  assert.deepEqual(calls, [[], ['a4b4'], ['a4b4', 'a7b7']]);
  assert.deepEqual(game.snapshot(), before);
  const deviceSetup = { cho: 'nbbn', han: 'nbnb' };
  const actualFen = initialFen({ cho: 'nbbn', han: 'bnbn' });
  let deviceJob = await (await post('record-review-start', { ...data, setup: deviceSetup, initialFen: actualFen })).json();
  for (let i = 0; i < 100 && deviceJob.status === 'running'; i++) {
    await new Promise(resolve => setTimeout(resolve, 10));
    deviceJob = await (await post('record-review-status', { recordJobId: deviceJob.recordJobId })).json();
  }
  assert.equal(deviceJob.status, 'complete');
  assert.equal(deviceJob.results[0].beforeFen, actualFen);
  assert.equal((await post('record-review-start', { ...data, initialFen: 'invalid' })).status, 400);
  assert.deepEqual(game.snapshot(), before);
});
