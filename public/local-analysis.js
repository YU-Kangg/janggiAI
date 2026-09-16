export function analyze(position, { workerFactory = () => new Worker('/analysis-worker.js'), onReady = () => {}, timeoutMs = 15000 } = {}) {
  let worker, timer, finish;
  const started = performance.now();
  let readyAt, depth = 0;
  const promise = new Promise((resolve, reject) => {
    finish = (error, result) => {
      clearTimeout(timer);
      worker?.terminate();
      worker = null;
      if (error) reject(error); else resolve(result);
    };
    try {
      worker = workerFactory();
      timer = setTimeout(() => finish(new Error('기기 분석 시간이 초과되었습니다. 다시 시도하세요.')), timeoutMs);
      worker.onerror = event => { console.error('분석 Worker 오류:', event.message); finish(new Error('이 브라우저에서 기기 분석을 실행하지 못했습니다.')); };
      worker.onmessage = ({ data }) => {
        if (!worker) return;
        if (data.type === 'error') return finish(new Error(data.message));
        if (data.type === 'ready') { readyAt = performance.now(); onReady(); }
        if (data.type !== 'line') return;
        const match = /^info depth (\d+)/.exec(data.line);
        if (match) depth = Number(match[1]);
        const best = /^bestmove (\S+)/.exec(data.line);
        if (best) {
          if (!position.legalMoves.includes(best[1])) return finish(new Error('현재 규칙과 일치하지 않는 분석 결과입니다.'));
          finish(null, { move: best[1], depth, loadMs: Math.round((readyAt ?? started) - started), totalMs: Math.round(performance.now() - started) });
        }
      };
      worker.postMessage({ initialFen: position.initialFen, moves: [...position.moves] });
    } catch (error) { finish(error); }
  });
  return { promise, cancel: () => finish(new DOMException('분석을 취소했습니다.', 'AbortError')) };
}
