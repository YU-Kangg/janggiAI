import test from 'node:test';
import assert from 'node:assert/strict';
import { parseAnalysis } from '../server/engine.js';
import { initialFen } from '../server/rules.js';

test('UCI 평가·깊이·노드·PV를 읽고 초 관점으로 통일', () => {
  const cp = parseAnalysis(
    'info depth 12 seldepth 16 multipv 1 score cp -18 nodes 58608 nps 219505 tbhits 0 time 267 pv a4b4 h10g8 h1g3\r\n',
    initialFen(), [],
  );
  assert.deepEqual(cp, {
    depth: 12, selDepth: 16, nodes: 58608, nps: 219505, timeMs: 267,
    evaluation: { unit: 'cp', sideToMove: -18, cho: -18 },
    pv: ['a4b4', 'h10g8', 'h1g3'],
  });
  const mate = parseAnalysis(
    'info depth 20 seldepth 22 multipv 1 score mate 3 nodes 999 nps 333 time 30 pv a7b7 a4b4\n',
    initialFen(), ['a4b4'],
  );
  assert.deepEqual(mate.evaluation, { unit: 'mate', sideToMove: 3, cho: -3 });
});

test('완전하지 않거나 잘못된 UCI 평가 행은 거부', () => {
  for (const output of [
    'bestmove a4b4\n',
    'info depth 8 multipv 1 score cp 2 nodes 3 nps 4 time 5 pv a4b4\n',
    'info depth 8 seldepth 9 multipv 1 score cp 2 nodes 3 nps 4 time 5 pv invalid\n',
  ]) assert.throws(() => parseAnalysis(output, initialFen(), []), /평가 정보/);
});
