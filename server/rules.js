import Module from 'ffish-es6';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const ffish = await Module({ wasmBinary: readFileSync(require.resolve('ffish-es6/ffish.wasm')) });
// This binding initializes variant piece tables when the first board is created.
const bootstrap = new ffish.Board('janggi');
bootstrap.delete();
export const arrangements = ['nbbn', 'bnbn', 'nbnb', 'bnnb'];
export const defaultSetup = { cho: 'nbbn', han: 'nbbn' };
export const ruleEngine = ffish.info();

export function initialFen(setup = defaultSetup) {
  if (!setup || !arrangements.includes(setup.cho) || !arrangements.includes(setup.han)) {
    throw Object.assign(new Error('초와 한의 차림을 올바르게 선택하세요.'), { status: 400 });
  }
  const row = order => `r${order.slice(0, 2)}a1a${order.slice(2)}r`;
  // Orders are specified from each player's own left to right.
  const han = row([...setup.han].reverse().join(''));
  const cho = row(setup.cho).toUpperCase();
  return `${han}/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/${cho} w - - 0 1`;
}

export function materialPoints(fen) {
  const weights = { r: 13, c: 7, n: 5, b: 3, a: 3, p: 2 };
  const points = { cho: 0, han: 1.5, hanBonus: 1.5 };
  for (const piece of fen.split(' ')[0]) {
    const value = weights[piece.toLowerCase()] || 0;
    points[piece === piece.toUpperCase() ? 'cho' : 'han'] += value;
  }
  return points;
}

const isPass = move => /^([a-i](?:10|[1-9]))\1$/.test(move || '');

export function rulePosition(moves, startFen = initialFen()) {
  if (ffish.validateFen(startFen, 'janggi') !== 1) throw new Error('유효하지 않은 시작 배치입니다.');
  const board = new ffish.Board('janggi', startFen);
  let previousBikjang = false;
  try {
    for (const move of moves) {
      if (board.isGameOver(true)) throw new Error('종료 이후의 착수가 포함되어 있습니다.');
      previousBikjang = board.isBikjang();
      if (!board.push(move)) throw new Error('기보에 합법적이지 않은 착수가 있습니다.');
    }
    const fen = board.fen();
    const rawLegal = board.legalMoves().split(' ').filter(Boolean);
    // Product policy: automatically adjudicate claimable repetition/n-move endings.
    const result = board.result(true);
    const over = result !== '*';
    let reason = null;
    if (over) {
      if (previousBikjang && board.isBikjang()) reason = '빅장 수락 · 점수 판정';
      else if (moves.length >= 2 && isPass(moves.at(-1)) && isPass(moves.at(-2))) reason = '양측 연속 한수쉼 · 점수 판정';
      else if (!rawLegal.length && board.isCheck()) reason = '외통';
      else if (board.result(false) === '*') reason = board.halfmoveClock() >= 100 ? '무포획 수 제한 · 점수 판정' : '반복 규칙 판정';
      else reason = '장기 규칙에 따른 종료';
    }
    return {
      fen, turn: board.turn() ? 'cho' : 'han', inCheck: board.isCheck(),
      bikjang: board.isBikjang(), legalMoves: over ? [] : rawLegal,
      points: materialPoints(fen),
      outcome: { over, result, winner: result === '1-0' ? 'cho' : result === '0-1' ? 'han' : null, reason },
    };
  } finally { board.delete(); }
}
