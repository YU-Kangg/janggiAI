import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyMove, summarizeReview, sacrificeEvidence, reviewEntry } from '../server/game.js';
import { rulePosition } from '../server/rules.js';

test('실험적 수 등급은 최선 수 일치와 cp 손실 경계를 적용', () => {
  assert.deepEqual(classifyMove(true, 999), {
    key: 'best', label: '최선', experimental: true, basis: 'exact-match',
  });
  const cases = [
    [0, 'best'], [15, 'best'], [16, 'good'], [40, 'good'],
    [41, 'inaccuracy'], [80, 'inaccuracy'], [81, 'mistake'], [160, 'mistake'], [161, 'blunder'],
  ];
  for (const [loss, key] of cases) {
    const result = classifyMove(false, loss);
    assert.equal(result.key, key, `${loss}cp`);
    assert.equal(result.experimental, true);
    assert.equal(result.basis, 'loss-cp');
  }
});

test('탁월수는 즉시 희생 후 보상이 필요하며 높은 평가만으로 부여하지 않음', () => {
  const before = 'r3k4/9/9/9/9/9/9/9/9/RN2K4 w - - 0 1';
  const sacrificed = 'r3k4/9/9/9/9/9/9/9/9/R3K4 w - - 0 1';
  const rewarded = '4k4/9/9/9/9/9/9/9/9/R3K4 w - - 0 1';
  assert.equal(sacrificeEvidence(before, [before], 'cho', { unit: 'cp', cho: 1200 }), null);
  assert.equal(sacrificeEvidence(before, [sacrificed], 'cho', { unit: 'cp', cho: 100 }), null);
  assert.equal(sacrificeEvidence(before, [before, before, sacrificed, rewarded], 'cho', { unit: 'cp', cho: 100 }), null);
  assert.equal(sacrificeEvidence(before, [sacrificed, rewarded], 'cho', { unit: 'cp', cho: -400 }), null);
  assert.equal(sacrificeEvidence(before, [sacrificed, rewarded], 'cho', { unit: 'cp', cho: 100 }).basis, 'sacrifice-material-gain');
  assert.equal(sacrificeEvidence(before, [before, sacrificed], 'cho', { unit: 'mate', cho: 3 }).basis, 'sacrifice-forced-win');
  assert.equal(sacrificeEvidence(before, [sacrificed], 'cho', { unit: 'mate', cho: -3 }), null);
  assert.equal(sacrificeEvidence(before, [sacrificed, rewarded], 'han', { unit: 'cp', cho: -100 }), null);
});

test('합법 수순에서 마를 희생하고 차를 얻는 최선수만 탁월로 승격', () => {
  const fen = '9/4k4/9/9/9/9/2r6/9/3K5/1NR6 w - - 0 1';
  const before = { ...rulePosition([], fen), moves: [], initialFen: fen };
  const after = rulePosition(['b1c3'], fen);
  const result = { move: 'b1c3', analysis: { evaluation: { unit: 'cp', cho: 100 }, pv: ['b1c3'] } };
  const afterResult = { move: 'c4c3', analysis: { evaluation: { unit: 'cp', cho: 100 }, pv: ['c4c3', 'c1c3'] } };
  const params = { revision: 1, ply: 1, position: before, result, afterPosition: after, afterResult, playedMove: 'b1c3' };
  assert.equal(reviewEntry(params).classification.key, 'brilliant');
  assert.equal(reviewEntry(params).classification.sacrificedPoints, 5);
  assert.equal(reviewEntry({ ...params, afterResult: { ...afterResult, analysis: { ...afterResult.analysis, pv: [] } } }).classification.key, 'best');
  const mateResult = { ...afterResult, analysis: { evaluation: { unit: 'mate', cho: 3 }, pv: ['c4c3'] } };
  assert.equal(reviewEntry({ ...params, afterResult: mateResult }).classification.key, 'brilliant');
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
    { ply: 1, side: 'cho', classification: { key: 'best' }, analysis: { lossCp: 0, before: { depth: 12, timeMs: 300 }, after: { timeMs: 280 } } },
    { ply: 2, side: 'han', classification: { key: 'inaccuracy' }, analysis: { lossCp: 50, before: { depth: 14, timeMs: 310 }, after: { timeMs: 290 } } },
    { ply: 3, side: 'cho', classification: { key: 'blunder' }, analysis: { lossCp: 200 } },
    { ply: 4, side: 'han', classification: { key: 'unclassified' }, analysis: { lossCp: null } },
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
  assert.deepEqual(summary.worstMove, { ply: 3, side: 'cho', lossCp: 200 });
  assert.equal(summary.averageLossCp, 83);
  assert.deepEqual(summary.bySide, {
    cho: { total: 2, keyMoves: 1, averageLossCp: 100 },
    han: { total: 2, keyMoves: 1, averageLossCp: 50 },
  });
});
