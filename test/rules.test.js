import test from 'node:test';
import assert from 'node:assert/strict';
import { arrangements, initialFen, rulePosition } from '../server/rules.js';
import { position } from '../server/engine.js';
import { Game } from '../server/game.js';

test('16개 차림 모두 규칙 라이브러리와 AI 실행 파일의 배치·합법 수가 일치', async () => {
  const unique = new Set();
  for (const cho of arrangements) for (const han of arrangements) {
    const fen = initialFen({ cho, han });
    unique.add(fen);
    const rules = rulePosition([], fen);
    const native = await position([], fen);
    assert.equal(rules.fen, native.fen);
    assert.deepEqual([...rules.legalMoves].sort(), [...native.legalMoves].sort(), `${cho}/${han}`);
    assert.deepEqual(rules.points, { cho: 72, han: 73.5, hanBonus: 1.5 });
    assert.equal(rules.outcome.over, false);
  }
  assert.equal(unique.size, 16);
  assert.ok(initialFen({ cho: 'bnbn', han: 'bnbn' }).startsWith('rnba1anbr/'), '한은 자기 진영 기준의 좌우를 뒤집어 저장');
});

test('연속 한수쉼은 점수승, 기물이 동점이면 한의 후수 보정 적용', () => {
  assert.equal(rulePosition(['e2e2']).outcome.over, false);
  const hanWin = rulePosition(['e2e2', 'e9e9']);
  assert.equal(hanWin.outcome.winner, 'han');
  assert.match(hanWin.outcome.reason, /한수쉼/);
  assert.deepEqual(hanWin.legalMoves, []);
  const fewerHanSoldiers = initialFen().replace('p1p1p1p1p', '2p1p1p1p');
  const choWin = rulePosition(['e2e2', 'e9e9'], fewerHanSoldiers);
  assert.equal(choWin.outcome.winner, 'cho');
  assert.equal(choWin.points.han, 71.5);
  assert.throws(() => rulePosition(['e2e2', 'e9e9', 'a4b4']), /종료 이후/);
});

test('빅장 제안·회피·수락과 점수 판정', () => {
  const fen = initialFen().replace('p1p1p1p1p', 'p1p3p1p').replace('P1P1P1P1P', 'P1P3P1P');
  const offered = rulePosition([], fen);
  assert.equal(offered.bikjang, true);
  assert.equal(offered.outcome.over, false);
  const declined = rulePosition(['e2d2'], fen);
  assert.equal(declined.bikjang, false);
  assert.equal(declined.outcome.over, false);
  const accepted = rulePosition(['e2e2'], fen);
  assert.equal(accepted.outcome.winner, 'han');
  assert.match(accepted.outcome.reason, /빅장/);
});

test('반복은 FEN만으로 판정하지 않고 전체 이력을 사용', () => {
  const cycle = ['a1a2', 'a10a9', 'a2a1', 'a9a10'];
  assert.equal(rulePosition(cycle).outcome.over, false);
  const repeated = rulePosition([...cycle, ...cycle]);
  assert.equal(repeated.outcome.winner, 'han');
  assert.match(repeated.outcome.reason, /반복/);
  assert.equal(rulePosition([], repeated.fen).outcome.over, false);
});

test('외통과 무포획 수 제한을 엔진 결과로 종료', () => {
  const mate = rulePosition([], '9/4k4/3RRR3/9/9/9/9/9/3K5/9 b - - 0 1');
  assert.equal(mate.outcome.winner, 'cho');
  assert.equal(mate.outcome.reason, '외통');
  const count = rulePosition([], initialFen().replace('0 1', '100 1'));
  assert.equal(count.outcome.winner, 'han');
  assert.match(count.outcome.reason, /수 제한/);
});

test('종료 뒤 착수·AI 차단, 무르기로 재개, 선택한 차림 초기화', async () => {
  const game = new Game();
  await game.act('move', { revision: 0, move: 'e2e2' });
  await game.act('move', { revision: 1, move: 'e9e9' });
  for (const action of ['move', 'recommend']) {
    await assert.rejects(game.act(action, { revision: 2, move: 'a4b4' }), /종료된 대국/);
  }
  const undone = await game.act('undo', { revision: 2 });
  assert.equal(undone.outcome.over, false);
  await assert.rejects(game.act('reset', { revision: 3, setup: { cho: 'invalid', han: 'nbbn' } }), /차림/);
  assert.equal((await game.snapshot()).revision, 3);
  const setup = { cho: 'bnbn', han: 'nbnb' };
  const reset = await game.act('reset', { revision: 3, setup });
  assert.equal(reset.fen, initialFen(setup));
  const ai = await game.act('recommend', { revision: 4 });
  assert.ok(reset.legalMoves.includes(ai.move));
});
