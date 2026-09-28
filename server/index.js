import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Game } from './game.js';
import { fileStorage } from './storage.js';
import { randomUUID } from 'node:crypto';
import { initialFen, rulePosition } from './rules.js';

export function createServer({ game = new Game() } = {}) {
  let queue = Promise.resolve();
  let recordReview = null;
  let recordJobId = null;
  let recordIdentity = null;
  const files = { '/': ['index.html', 'text/html'], '/app.js': ['app.js', 'text/javascript'], '/style.css': ['style.css', 'text/css'] };
  for (const name of ['analysis-worker.js', 'local-analysis.js']) files[`/${name}`] = [name, 'text/javascript'];
  for (const name of ['stockfish.js', 'stockfish.worker.js', 'stockfish.wasm', 'Copying.txt']) {
    files[`/engine/${name}`] = [`../node_modules/fairy-stockfish-nnue.wasm/${name}`, name.endsWith('.wasm') ? 'application/wasm' : name.endsWith('.js') ? 'text/javascript' : 'text/plain'];
  }
  const server = http.createServer(async (req, res) => {
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    const json = (status, value) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify(value));
    };
    try {
      if (req.headers.origin && req.headers.origin !== `http://${req.headers.host}`) {
        return json(403, { error: '외부 사이트의 요청은 허용하지 않습니다.' });
      }
      if (req.method === 'GET' && files[req.url]) {
        const [name, type] = files[req.url];
        const body = await readFile(new URL(`../public/${name}`, import.meta.url));
        res.writeHead(200, { 'Content-Type': `${type}; charset=utf-8` });
        return res.end(body);
      }
      const action = /^\/api\/(move|undo|reset|resign|draw|recommend|cancel-ai|resume-ai|review|review-analysis|review-start|review-status|review-latest|review-cancel|record-review-start|record-review-status|variation)$/.exec(req.url)?.[1];
      if (!(req.method === 'GET' && req.url === '/api/game') && !(req.method === 'POST' && action)) {
        return json(404, { error: '요청 경로를 찾을 수 없습니다.' });
      }
      let body = '';
      for await (const chunk of req) {
        body += chunk;
        if (body.length > (action === 'record-review-start' ? 32768 : 2048)) return json(413, { error: '요청이 너무 큽니다.' });
      }
      let data = {};
      try { data = body ? JSON.parse(body) : {}; }
      catch { return json(400, { error: '요청 형식이 올바르지 않습니다.' }); }
      if (!data || typeof data !== 'object' || Array.isArray(data)) return json(400, { error: '요청 형식이 올바르지 않습니다.' });
      if (action === 'record-review-start') {
        if (!data.setup || !Array.isArray(data.moves) || !data.moves.length || data.moves.length > 1024
          || data.moves.some(move => typeof move !== 'string') || !Number.isSafeInteger(data.revision) || data.revision < 0) {
          return json(400, { error: '분석할 기보 형식이 올바르지 않습니다.' });
        }
        const identity = JSON.stringify([data.revision, data.setup.cho, data.setup.han, data.initialFen, data.moves]);
        if (recordIdentity === identity && ['running', 'complete'].includes(recordReview?.fullReviewJob?.status)) {
          return json(200, { ...recordReview.fullReviewSnapshot(), recordJobId });
        }
        if (recordReview?.fullReviewJob?.status === 'running') return json(409, { error: '이미 다른 기보 분석이 진행 중입니다.' });
        let position;
        let analysisSetup = { ...data.setup };
        try {
          // Legacy device saves describe Han's row in board order; preserve the actual position.
          if (data.initialFen && data.initialFen !== initialFen(analysisSetup)) {
            analysisSetup.han = [...analysisSetup.han].reverse().join('');
            if (data.initialFen !== initialFen(analysisSetup)) throw new Error('Starting position mismatch');
          }
          position = rulePosition(data.moves, initialFen(analysisSetup));
        }
        catch { return json(400, { error: '합법적인 장기 기보가 아닙니다.' }); }
        recordReview = new Game({ recommendMove: game.recommendMove });
        recordReview.moves = [...data.moves];
        recordReview.setup = analysisSetup;
        recordReview.state = position;
        recordReview.revision = data.revision;
        recordJobId = randomUUID();
        recordIdentity = identity;
        return json(200, { ...recordReview.startFullReview(), recordJobId });
      }
      if (action === 'record-review-status') {
        if (!recordReview || data.recordJobId !== recordJobId) return json(404, { error: '기보 분석을 찾을 수 없습니다. 다시 시작해 주세요.' });
        return json(200, { ...recordReview.fullReviewSnapshot(), recordJobId });
      }
      const task = queue.then(() => action ? game.act(action, data) : game.snapshot());
      queue = task.catch(() => {});
      json(200, await task);
    } catch (error) {
      json(error.status || 503, { error: error.message });
    }
  });
  server.on('close', () => { game.stopAi(); game.stopFullReview(); recordReview?.stopFullReview(); });
  return server;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT || 3000);
  const storage = fileStorage(fileURLToPath(new URL('../.local/current-game.json', import.meta.url)));
  const server = createServer({ game: new Game({ storage }) });
  server.on('error', error => { console.error(error.message); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(`장기 연습판: http://127.0.0.1:${port}`));
}
