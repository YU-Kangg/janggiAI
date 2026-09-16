/* Fairy-Stockfish runs here, away from the page's UI thread. */
importScripts('/engine/stockfish.js');
let engine;
onmessage = async ({ data }) => {
  try {
    engine = await Stockfish({ locateFile: name => `/engine/${name}`, mainScriptUrlOrBlob: `${location.origin}/engine/stockfish.js` });
    let ready = false;
    engine.addMessageListener(line => {
      if (line === 'uciok') {
        for (const command of ['setoption name UCI_Variant value janggi', 'setoption name Threads value 1', 'setoption name Hash value 16', 'setoption name Use NNUE value false', 'isready']) engine.postMessage(command);
      } else if (line === 'readyok' && !ready) {
        ready = true;
        postMessage({ type: 'ready' });
        engine.postMessage(`position fen ${data.initialFen} moves ${data.moves.join(' ')}`);
        engine.postMessage('go movetime 300');
      } else if (line.startsWith('info depth ') || line.startsWith('bestmove ')) {
        postMessage({ type: 'line', line });
      }
    });
    engine.postMessage('uci');
  } catch (error) { postMessage({ type: 'error', message: error.message }); }
};
