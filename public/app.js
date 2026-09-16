import { analyze } from './local-analysis.js';
const $ = id => document.getElementById(id);
let analysisJob = null;
function cancelAnalysis() { analysisJob?.cancel(); analysisJob = null; }
const names = { k: '궁', a: '사', r: '차', n: '마', b: '상', c: '포', p: '졸' };
let game, selected = null, suggestion = null, busy = false;
let review = null;
for (const side of ['cho', 'han']) {
  for (const value of ['nbbn', 'bnbn', 'nbnb', 'bnnb']) {
    const option = document.createElement('option');
    option.value = value;
    option.textContent = [...value].map(char => char === 'n' ? '마' : '상').join(' · ');
    $(`${side}-setup`).append(option);
  }
}
const split = move => move.match(/^([a-i](?:10|[1-9]))([a-i](?:10|[1-9]))$/)?.slice(1);
const describe = move => { const [from, to] = split(move); return from === to ? '한수쉼' : `${from} → ${to}`; };
const svg = document.querySelector('svg');
for (let x = .5; x < 9; x++) svg.innerHTML += `<line x1="${x}" y1=".5" x2="${x}" y2="9.5"/>`;
for (let y = .5; y < 10; y++) svg.innerHTML += `<line x1=".5" y1="${y}" x2="8.5" y2="${y}"/>`;
for (const y of [.5, 7.5]) svg.innerHTML += `<line x1="3.5" y1="${y}" x2="5.5" y2="${y + 2}"/><line x1="5.5" y1="${y}" x2="3.5" y2="${y + 2}"/>`;

function pieces(game) {
  const board = {};
  game.fen.split(' ')[0].split('/').forEach((row, index) => {
    let file = 0;
    for (const char of row) {
      if (/\d/.test(char)) file += Number(char);
      else board[`${String.fromCharCode(97 + file++)}${10 - index}`] = char;
    }
  });
  return board;
}

function render() {
  renderBoard(review || game, game);
}

function renderBoard(game, live) {
  if (!game) return;
  const board = pieces(game);
  const aiTurn = game.mode === 'ai' && game.turn !== game.humanSide;
  const flipped = game.mode === 'ai' && game.humanSide === 'han';
  const targets = game.legalMoves.filter(move => split(move)[0] === selected && split(move)[1] !== selected).map(move => split(move)[1]);
  $('squares').replaceChildren();
  for (let row = 0; row < 10; row++) for (let column = 0; column < 9; column++) {
    const rank = flipped ? row + 1 : 10 - row;
    const file = flipped ? 8 - column : column;
    const square = `${String.fromCharCode(97 + file)}${rank}`;
    const piece = board[square];
    const side = piece && (piece === piece.toUpperCase() ? 'cho' : 'han');
    const label = piece ? (piece === 'p' ? '병' : names[piece.toLowerCase()]) : '빈 자리';
    const button = document.createElement('button');
    button.className = ['square', selected === square ? 'selected' : '', targets.includes(square) ? 'target' : '', suggestion && split(suggestion).includes(square) ? 'suggested' : ''].join(' ');
    button.disabled = busy || !!review || game.outcome.over || aiTurn;
    button.setAttribute('aria-label', `${square} ${side ? (side === 'cho' ? '초 ' : '한 ') : ''}${label}`);
    button.setAttribute('aria-pressed', String(selected === square));
    if (piece) { const token = document.createElement('span'); token.className = `piece ${side}`; token.textContent = label; button.append(token); }
    button.onclick = () => {
      if (selected && targets.includes(square)) return act('move', { move: selected + square });
      selected = side === game.turn && selected !== square ? square : null;
      render();
    };
    $('squares').append(button);
  }
  $('status').textContent = `${game.turn === 'cho' ? '초' : '한'} 차례 · ${game.moves.length}수${game.inCheck ? ' · 장군입니다' : ''}${busy ? ' · 처리 중…' : ''}`;
  if (game.outcome.over) $('status').textContent = `${game.outcome.winner ? (game.outcome.winner === 'cho' ? '초 승리' : '한 승리') : '무승부'} · ${game.outcome.reason}`;
  else if (game.bikjang) $('status').textContent += ' · 빅장! 피하거나 한수쉼으로 수락하세요.';
  $('points').textContent = `기물 점수: 초 ${game.points.cho} · 한 ${game.points.han} (후수 보정 포함)`;
  if (review) $('status').textContent = `복기 ${game.moves.length}/${live.moves.length}수 · ${$('status').textContent}`;
  for (const id of ['cho-setup', 'han-setup', 'new-game', 'mode']) $(id).disabled = busy;
  $('human-side').disabled = busy || $('mode').value !== 'ai';
  $('pass').disabled = busy || !!review || aiTurn || !game.legalMoves.some(move => split(move)[0] === split(move)[1]);
  $('undo').disabled = busy || !!review || !game.canUndo;
  $('undo').textContent = game.mode === 'ai' ? '내 이전 차례로 무르기' : '한 수 무르기';
  $('reset').disabled = busy || !!review;
  $('new-game').disabled = busy || !!review;
  $('recommend').disabled = busy || !!analysisJob || !!review || aiTurn || !game.legalMoves.length;
  $('cancel-analysis').hidden = !analysisJob;
  $('cancel-ai').hidden = game.ai.status !== 'thinking';
  $('cancel-ai').disabled = busy;
  $('resume-ai').hidden = !['paused', 'error'].includes(game.ai.status);
  $('resume-ai').disabled = busy || !!review;
  $('review-first').disabled = busy || !live.moves.length;
  $('review-prev').disabled = busy || !game.moves.length;
  $('review-next').disabled = busy || !review || game.moves.length >= live.moves.length;
  $('review-live').disabled = busy || !review;
  $('review-state').textContent = review ? `복기 중: ${game.moves.length}/${live.moves.length}수 · 착수하려면 현재 대국으로 돌아오세요.` : `현재 대국 · ${live.moves.length}수 · 자동 저장`;
  const sideLabel = game.humanSide === 'cho' ? '초' : '한';
  const aiMessage = { thinking: 'AI가 생각하고 있습니다…', paused: 'AI 응수가 일시정지되었습니다.', error: `AI 응수 실패: ${game.ai.error || ''}` }[game.ai.status];
  $('ai-state').textContent = game.mode === 'ai' ? `내 진영: ${sideLabel} · ${aiMessage || (game.outcome.over ? '대국 종료' : '내 차례입니다.')}` : '초와 한을 직접 조작하는 연습 모드입니다.';
  $('history').replaceChildren();
  for (const [index, move] of live.moves.entries()) {
    const item = document.createElement('li');
    const button = document.createElement('button');
    button.textContent = `${index % 2 ? '한' : '초'} ${describe(move)}`;
    button.disabled = busy;
    button.setAttribute('aria-current', String(!!review && index + 1 === game.moves.length));
    button.onclick = () => showReview(index + 1);
    item.append(button); $('history').append(item);
  }
  if (!game.moves.length) { const empty = document.createElement('p'); empty.textContent = '기물을 선택한 뒤 표시된 자리로 이동하세요.'; $('history').append(empty); }
}

async function request(path, data) {
  const response = await fetch(`/api/${path}`, data ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) } : {});
  const result = await response.json();
  if (!response.ok) throw new Error(result.error);
  return result;
}

async function act(action, data = {}) {
  if (busy) return;
  cancelAnalysis();
  busy = true; $('error').textContent = ''; render();
  try {
    const result = await request(action, { ...data, revision: game.revision });
    if (action === 'recommend') {
      suggestion = result.move;
      $('advice').textContent = `추천: ${describe(suggestion)} · 빠른 분석 결과`;
    } else {
      game = result; review = null; selected = null; suggestion = null;
      $('advice').textContent = game.outcome.over ? '대국이 종료되어 추천을 중단했습니다.' : '현재 장면에서 AI 추천을 받을 수 있습니다.';
    }
  } catch (error) {
    $('error').textContent = error.message;
    // A reply may have arrived just before cancel/undo; refresh instead of staying stale.
    try { receive(await request('game')); } catch { /* Keep the original error visible. */ }
  }
  finally { busy = false; render(); }
}
$('pass').onclick = () => act('move', { move: game.legalMoves.find(move => split(move)[0] === split(move)[1]) });
$('undo').onclick = () => act('undo');
$('reset').onclick = () => { if (confirm('현재 착수 기록을 지우고 처음부터 시작할까요?')) act('reset'); };
$('new-game').onclick = () => {
  if (!game.moves.length || confirm('현재 기보를 지우고 선택한 차림으로 시작할까요?')) {
    act('reset', { setup: { cho: $('cho-setup').value, han: $('han-setup').value }, mode: $('mode').value, humanSide: $('human-side').value });
  }
};
$('recommend').onclick = async () => {
  if (analysisJob || busy || review || !game?.legalMoves.length) return;
  if (!crossOriginIsolated || typeof SharedArrayBuffer === 'undefined') {
    $('error').textContent = '기기 분석에는 보안 연결(HTTPS 또는 localhost)과 지원 브라우저가 필요합니다.';
    return;
  }
  const position = game;
  $('error').textContent = ''; suggestion = null;
  $('advice').textContent = '이 기기에 분석 엔진을 불러오고 있습니다…';
  const job = analyze(position, { onReady: () => { $('advice').textContent = '이 기기의 CPU로 분석하고 있습니다…'; } });
  analysisJob = job; render();
  try {
    const result = await job.promise;
    if (analysisJob !== job || game.revision !== position.revision || review) return;
    suggestion = result.move;
    $('advice').textContent = `추천: ${describe(result.move)} · 기기 분석 · 깊이 ${result.depth} · 로딩 ${result.loadMs}ms / 전체 ${result.totalMs}ms`;
  } catch (error) {
    if (analysisJob === job && error.name !== 'AbortError') $('error').textContent = error.message;
  } finally { if (analysisJob === job) analysisJob = null; render(); }
};
$('cancel-analysis').onclick = () => { cancelAnalysis(); $('advice').textContent = '기기 분석을 취소했습니다.'; render(); };
document.addEventListener('visibilitychange', () => { if (document.hidden && analysisJob) { cancelAnalysis(); $('advice').textContent = '화면을 떠나 기기 분석을 중단했습니다.'; render(); } });
$('cancel-ai').onclick = () => act('cancel-ai');
$('resume-ai').onclick = () => act('resume-ai');
$('mode').onchange = () => render();

async function showReview(ply) {
  if (busy || !game) return;
  cancelAnalysis();
  busy = true; selected = null; suggestion = null; $('error').textContent = ''; render();
  try {
    review = await request('review', { ply, revision: game.revision });
    $('advice').textContent = '복기는 기보 조회만 지원합니다. 추천은 현재 대국에서 받을 수 있습니다.';
  } catch (error) { $('error').textContent = error.message; }
  finally { busy = false; render(); }
}
$('review-first').onclick = () => showReview(0);
$('review-prev').onclick = () => showReview((review || game).moves.length - 1);
$('review-next').onclick = () => showReview(review.moves.length + 1);
$('review-live').onclick = () => { review = null; $('advice').textContent = '현재 장면에서 AI 추천을 받을 수 있습니다.'; render(); };

function receive(next) {
  if (game && next.revision <= game.revision) return;
  cancelAnalysis();
  if (!game) {
    for (const side of ['cho', 'han']) $(`${side}-setup`).value = next.setup[side];
    $('mode').value = next.mode;
    $('human-side').value = next.humanSide;
  }
  game = next;
  review = null;
  selected = null;
  suggestion = null;
  $('advice').textContent = game.outcome.over ? '대국이 종료되어 추천을 중단했습니다.' : '현재 장면에서 AI 추천을 받을 수 있습니다.';
  render();
}

// Refresh AI responses and other tabs without overlapping requests or losing a selection.
async function poll() {
  try { if (!busy) { const next = await request('game'); if (!busy) receive(next); } }
  catch (error) {
    $('error').textContent = error.message;
    if (!game) $('status').textContent = '장기판 연결을 다시 시도하고 있습니다…';
  } finally { setTimeout(poll, 500); }
}
await poll();
