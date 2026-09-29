import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { AuthService, MemoryAuthRepository } from '../server/auth.js';
import { createServer } from '../server/index.js';

async function startServer(t, auth = new AuthService()) {
  const server = createServer({ auth });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => server.close());
  return `http://127.0.0.1:${server.address().port}`;
}

test('회원가입은 이메일을 정규화하고 비밀번호 원문 없이 저장', async () => {
  const repository = new MemoryAuthRepository();
  const auth = new AuthService({ repository, now: () => Date.UTC(2026, 8, 29) });
  const user = await auth.register({ email: ' Player@Example.COM ', password: '긴 비밀번호 1234', name: ' 장기인 ' });
  assert.equal(user.email, 'player@example.com');
  assert.equal(user.name, '장기인');
  assert.equal(user.role, 'user');
  assert.equal(user.password, undefined);
  const saved = await repository.findUserByEmail('player@example.com');
  assert.equal(saved.password.algorithm, 'scrypt');
  assert.ok(!JSON.stringify(saved).includes('긴 비밀번호 1234'));
  await assert.rejects(auth.register({ email: 'PLAYER@example.com', password: 'another password', name: '다른 사용자' }), /이미 가입/);
});

test('로그인 세션은 조회·로그아웃·만료를 처리하고 오류는 계정 존재 여부를 숨김', async () => {
  let now = Date.UTC(2026, 8, 29);
  const auth = new AuthService({ now: () => now });
  const user = await auth.register({ email: 'player@example.com', password: 'correct password', name: '장기인' });
  await assert.rejects(auth.login({ email: user.email, password: 'wrong password' }), /이메일 또는 비밀번호/);
  await assert.rejects(auth.login({ email: 'nobody@example.com', password: 'wrong password' }), /이메일 또는 비밀번호/);
  const login = await auth.login({ email: 'PLAYER@example.com', password: 'correct password' });
  assert.equal(login.token.length, 43);
  assert.equal((await auth.session(login.token)).user.id, user.id);
  await auth.logout(login.token);
  assert.equal(await auth.session(login.token), null);
  const expiring = await auth.login({ email: user.email, password: 'correct password' });
  now += 8 * 24 * 60 * 60 * 1000;
  assert.equal(await auth.session(expiring.token), null);
});

test('인증 HTTP API는 HttpOnly 쿠키와 Bearer 세션을 지원하고 비밀번호를 노출하지 않음', async t => {
  const base = await startServer(t);
  let response = await fetch(`${base}/api/auth/register`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'player@example.com', password: 'correct password', name: '장기인' }),
  });
  assert.equal(response.status, 201);
  assert.equal((await response.json()).user.password, undefined);
  response = await fetch(`${base}/api/auth/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'player@example.com', password: 'correct password' }),
  });
  assert.equal(response.status, 200);
  const cookie = response.headers.get('set-cookie');
  assert.match(cookie, /janggi_session=.*HttpOnly.*SameSite=Lax.*Max-Age=/);
  const webLogin = await response.json();
  assert.equal(webLogin.token, undefined);
  assert.equal(webLogin.user.password, undefined);
  response = await fetch(`${base}/api/auth/session`, { headers: { Cookie: cookie.split(';')[0] } });
  assert.equal(response.status, 200);
  response = await fetch(`${base}/api/auth/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Janggi-Client': 'mobile' },
    body: JSON.stringify({ email: 'player@example.com', password: 'correct password' }),
  });
  const login = await response.json();
  assert.equal(login.token.length, 43);
  assert.equal(login.user.password, undefined);
  response = await fetch(`${base}/api/auth/session`, { headers: { Authorization: `Bearer ${login.token}` } });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).user.email, 'player@example.com');
  response = await fetch(`${base}/api/auth/logout`, { method: 'POST', headers: { Authorization: `Bearer ${login.token}` } });
  assert.equal(response.status, 200);
  assert.match(response.headers.get('set-cookie'), /Max-Age=0/);
  response = await fetch(`${base}/api/auth/session`, { headers: { Authorization: `Bearer ${login.token}` } });
  assert.equal(response.status, 401);
  for (let attempt = 0; attempt < 5; attempt++) {
    response = await fetch(`${base}/api/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'player@example.com', password: 'wrong password' }),
    });
    assert.equal(response.status, 401);
  }
  response = await fetch(`${base}/api/auth/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'player@example.com', password: 'correct password' }),
  });
  assert.equal(response.status, 429);
});

test('회원 입력과 손상된 저장 데이터는 거부', async () => {
  const auth = new AuthService();
  await assert.rejects(auth.register({ email: 'invalid', password: 'correct password', name: '장기인' }), /이메일/);
  await assert.rejects(auth.register({ email: 'a@example.com', password: 'short', name: '장기인' }), /8~128자/);
  await assert.rejects(auth.register({ email: 'a@example.com', password: 'correct password', name: '한' }), /2~20자/);
  const repository = new MemoryAuthRepository();
  repository.users.set('broken@example.com', { id: 'id', email: null, name: '장기인', role: 'user', createdAt: 'invalid',
    password: { algorithm: 'scrypt', salt: '', hash: '' } });
  await assert.rejects(new AuthService({ repository }).login({
    email: 'broken@example.com', password: 'correct password',
  }), /회원 정보/);
});
