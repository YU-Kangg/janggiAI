import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { initialFen } from './rules.js';

export const enginePath = process.env.JANGGI_ENGINE_PATH || fileURLToPath(
  new URL('../.local/fairy-stockfish_x86-64.exe', import.meta.url),
);
const movePattern = /^[a-i](?:10|[1-9])[a-i](?:10|[1-9])$/;

export function parseAnalysis(output, startFen, moves) {
  const lines = output.match(/^info depth .*$/gm) || [];
  const line = lines.filter(value => /\bmultipv 1\b/.test(value) && /\bscore (?:cp|mate) -?\d+\b/.test(value) && /\bpv\s+\S+/.test(value)).at(-1);
  if (!line) throw new Error('엔진 평가 정보를 읽지 못했습니다.');
  const integer = name => Number(line.match(new RegExp(`\\b${name} (\\d+)\\b`))?.[1]);
  const score = line.match(/\bscore (cp|mate) (-?\d+)\b/);
  const pv = line.match(/\bpv\s+(.+)$/)?.[1].trim().split(/\s+/) || [];
  if (!score || pv.length === 0 || pv.some(move => !movePattern.test(move))) throw new Error('엔진 평가 정보를 읽지 못했습니다.');
  const initialChoTurn = startFen.trim().split(/\s+/)[1] === 'w';
  const choTurn = moves.length % 2 === 0 ? initialChoTurn : !initialChoTurn;
  const sideToMove = Number(score[2]);
  const fields = { depth: integer('depth'), selDepth: integer('seldepth'), nodes: integer('nodes'), nps: integer('nps'), timeMs: integer('time') };
  if (Object.values(fields).some(value => !Number.isSafeInteger(value) || value < 0)) throw new Error('엔진 평가 정보를 읽지 못했습니다.');
  return { ...fields, evaluation: { unit: score[1], sideToMove, cho: choTurn ? sideToMove : -sideToMove }, pv };
}

// Small local prototype: each request owns its engine process and search state.
// Replace with a bounded worker pool when adding server reviews.
export function runEngine(moves, analyze = false, startFen = initialFen(), { signal, movetimeMs = 300 } = {}) {
  if (signal?.aborted) return Promise.reject(new DOMException('분석을 취소했습니다.', 'AbortError'));
  if (!Array.isArray(moves) || moves.some(move => !movePattern.test(move))) {
    return Promise.reject(new Error('잘못된 기보 형식입니다.'));
  }
  return new Promise((resolve, reject) => {
    const child = spawn(enginePath, [], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let output = '';
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      signal?.removeEventListener('abort', onAbort);
      child.kill();
      if (error) reject(error);
      else resolve(output);
    };
    const timer = setTimeout(() => finish(new Error('엔진 응답 시간이 초과되었습니다.')), 8000);
    const onAbort = () => finish(new DOMException('분석을 취소했습니다.', 'AbortError'));
    signal?.addEventListener('abort', onAbort, { once: true });
    child.on('error', () => finish(new Error('장기 엔진을 실행할 수 없습니다. README의 엔진 설치 경로를 확인하세요.')));
    child.stdin.on('error', error => finish(error));
    child.stderr.on('data', () => {});
    child.on('close', () => { if (!settled) finish(new Error('장기 엔진이 예기치 않게 종료되었습니다.')); });
    child.stdout.on('data', chunk => {
      output += chunk.toString();
      // isready may answer while perft/search is still running; wait for its own terminator.
      if (analyze ? /^bestmove [^\r\n]+\r?\n/m.test(output) : /^Nodes searched: \d+\r?\n/m.test(output)) finish();
    });
    child.stdin.write([
      'uci',
      'setoption name UCI_Variant value janggi',
      'setoption name Threads value 1',
      'setoption name Hash value 32',
      'setoption name Use NNUE value true',
      'setoption name MultiPV value 1',
      'ucinewgame',
      `position fen ${startFen}${moves.length ? ` moves ${moves.join(' ')}` : ''}`,
      ...(analyze ? [`go movetime ${Math.max(50, Math.min(3000, Math.round(movetimeMs)))}`] : ['d', 'go perft 1', 'isready']),
      '',
    ].join('\n'));
  });
}

export async function position(moves, startFen = initialFen()) {
  const output = await runEngine(moves, false, startFen);
  const fen = output.match(/^Fen:\s*(.+)\r?$/m)?.[1].trim();
  if (!fen) throw new Error('장기판 정보를 읽지 못했습니다.');
  const legalMoves = [...output.matchAll(/^([a-i](?:10|[1-9])[a-i](?:10|[1-9])): 1\r?$/gm)].map(match => match[1]);
  const checkers = output.match(/^Checkers:[ \t]*([^\r\n]*)/m)?.[1].trim();
  return { fen, legalMoves, inCheck: Boolean(checkers), turn: fen.split(' ')[1] === 'w' ? 'cho' : 'han' };
}

export async function recommend(moves, startFen = initialFen(), options = {}) {
  const output = await runEngine(moves, true, startFen, options);
  if (!output.includes('NNUE evaluation using janggi-9991472750de.nnue enabled')) {
    throw new Error('장기 NNUE 평가망이 활성화되지 않았습니다.');
  }
  const move = output.match(/^bestmove (\S+)/m)?.[1];
  if (!movePattern.test(move || '')) throw new Error('추천할 수를 찾지 못했습니다.');
  const analysis = parseAnalysis(output, startFen, moves);
  if (analysis.pv[0] !== move) throw new Error('추천 수와 평가 수순이 일치하지 않습니다.');
  return { move, budgetMs: Math.max(50, Math.min(3000, Math.round(options.movetimeMs ?? 300))), source: 'local-server', analysis };
}
