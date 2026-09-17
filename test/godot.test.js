import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { resolve } from 'node:path';
import { createServer } from '../server/index.js';

const executable = process.env.JANGGI_GODOT_PATH || resolve('.local/godot/Godot_v4.7.2-stable_win64_console.exe');
test('Godot 실제 클라이언트: 대국·복기 서버 분석·초한 AI 응수·연결 오류', { skip: !existsSync(executable), timeout: 45000 }, async t => {
  const server = createServer();
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const child = spawn(executable, ['--headless', '--path', resolve('godot'), '--script', 'res://smoke.gd', '--', `--server=http://127.0.0.1:${server.address().port}`], { windowsHide: true });
  t.after(() => child.kill());
  let output = '';
  child.stdout.on('data', chunk => { output += chunk; });
  child.stderr.on('data', chunk => { output += chunk; });
  const [code] = await once(child, 'close');
  assert.equal(code, 0, output);
  assert.match(output, /GODOT_SMOKE_OK/);
  assert.doesNotMatch(output, /SCRIPT ERROR|ERROR:/);
});
