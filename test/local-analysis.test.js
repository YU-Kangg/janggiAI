import test from 'node:test';
import assert from 'node:assert/strict';
import { analyze } from '../public/local-analysis.js';

const position = { initialFen: 'start', moves: ['a4b4'], legalMoves: ['a7b7'] };
function fake() {
  return { stopped: false, postMessage(data) { this.input = data; }, terminate() { this.stopped = true; } };
}
test('기기 분석은 전체 기보를 전달하고 합법 결과만 반환', async () => {
  const worker = fake();
  const job = analyze(position, { workerFactory: () => worker });
  assert.deepEqual(worker.input.moves, position.moves);
  worker.onmessage({ data: { type: 'ready' } });
  worker.onmessage({ data: { type: 'line', line: 'info depth 5 nodes 100' } });
  worker.onmessage({ data: { type: 'line', line: 'bestmove a7b7' } });
  const result = await job.promise;
  assert.equal(result.move, 'a7b7');
  assert.equal(result.depth, 5);
  assert.equal(worker.stopped, true);
});
test('취소는 Worker 종료, 늦은 결과 무시; 불법 수 거부', async () => {
  const worker = fake();
  const job = analyze(position, { workerFactory: () => worker });
  job.cancel();
  worker.onmessage({ data: { type: 'line', line: 'bestmove a7b7' } });
  await assert.rejects(job.promise, { name: 'AbortError' });
  assert.equal(worker.stopped, true);
  const invalid = fake();
  const another = analyze(position, { workerFactory: () => invalid });
  invalid.onmessage({ data: { type: 'line', line: 'bestmove a1a10' } });
  await assert.rejects(another.promise, /일치하지/);
  assert.equal(invalid.stopped, true);
});
test('로딩 실패와 시간 초과 시 Worker 정리', async () => {
  const worker = fake();
  const job = analyze(position, { workerFactory: () => worker, timeoutMs: 5 });
  await assert.rejects(job.promise, /초과/);
  assert.equal(worker.stopped, true);
  const failed = analyze(position, { workerFactory: () => { throw Error('unsupported'); } });
  await assert.rejects(failed.promise, /unsupported/);
});
