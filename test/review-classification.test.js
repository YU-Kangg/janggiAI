import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyMove, summarizeReview } from '../server/game.js';

test('실험적 수 등급은 최선 수 일치와 cp 손실 경계를 적용', () => {
  assert.deepEqual(classifyMove(true, 999), {
    key: 'best', label: '최선', experimental: true, basis: 'exact-match',
  });
  const cases = [
    [0, 'excellent'], [15, 'excellent'], [16, 'good'], [40, 'good'],
    [41, 'inaccuracy'], [80, 'inaccuracy'], [81, 'mistake'], [160, 'mistake'], [161, 'blunder'],
  ];
  for (const [loss, key] of cases) {
    const result = classifyMove(false, loss);
    assert.equal(result.key, key, `${loss}cp`);
    assert.equal(result.experimental, true);
    assert.equal(result.basis, 'loss-cp');
  }
});

test('cp로 비교할 수 없는 종료·mate·평가 누락은 등급에서 제외', () => {
  for (const loss of [null, undefined, Number.NaN]) {
    assert.deepEqual(classifyMove(false, loss), {
      key: 'unclassified', label: '분류 제외', experimental: true, basis: 'unavailable',
    });
  }
});

test('전체 리뷰 요약은 등급 수와 핵심 수 및 평균 손실을 집계', () => {
  const results = [
    { side: 'cho', classification: { key: 'best' }, analysis: { lossCp: 0, before: { depth: 12, timeMs: 300 }, after: { timeMs: 280 } } },
    { side: 'han', classification: { key: 'inaccuracy' }, analysis: { lossCp: 50, before: { depth: 14, timeMs: 310 }, after: { timeMs: 290 } } },
    { side: 'cho', classification: { key: 'blunder' }, analysis: { lossCp: 200 } },
    { side: 'han', classification: { key: 'unclassified' }, analysis: { lossCp: null } },
  ];
  const summary = summarizeReview(results);
  assert.equal(summary.total, 4);
  assert.equal(summary.counts.best, 1);
  assert.equal(summary.counts.inaccuracy, 1);
  assert.equal(summary.counts.blunder, 1);
  assert.equal(summary.counts.unclassified, 1);
  assert.equal(summary.keyMoves, 2);
  assert.equal(summary.comparableMoves, 3);
  assert.equal(summary.bestMoveRate, 25);
  assert.equal(summary.averageDepth, 13);
  assert.equal(summary.totalAnalysisMs, 1180);
  assert.equal(summary.averageLossCp, 83);
  assert.deepEqual(summary.bySide, {
    cho: { total: 2, keyMoves: 1, averageLossCp: 100 },
    han: { total: 2, keyMoves: 1, averageLossCp: 50 },
  });
});
