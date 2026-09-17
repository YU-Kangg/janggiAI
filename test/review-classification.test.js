import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyMove } from '../server/game.js';

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
