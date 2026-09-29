import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { MySqlAuthRepository, authSchemaStatements } from '../server/mysql-auth-repository.js';

class FakePool {
  calls = [];
  rows = [];
  async execute(sql, values = []) {
    this.calls.push({ method: 'execute', sql, values });
    if (/^\s*SELECT/u.test(sql)) return [this.rows, []];
    return [{ affectedRows: 1 }, []];
  }
  async query(sql) { this.calls.push({ method: 'query', sql }); return [[{ ok: 1 }], []]; }
  async end() { this.calls.push({ method: 'end' }); }
}

const storedRow = {
  id: '68276784-6241-4a02-a87b-4d333f261878', email: 'player@example.com', display_name: '장기인', role: 'user',
  password_algorithm: 'scrypt', password_salt: Buffer.alloc(16).toString('base64'),
  password_hash: Buffer.alloc(32).toString('base64'), created_at: new Date('2026-09-29T00:00:00.000Z'),
};

test('MySQL 인증 저장소는 회원·세션 스키마와 연결을 초기화', async () => {
  const pool = new FakePool();
  const repository = new MySqlAuthRepository(pool, { autoMigrate: true });
  await repository.initialize();
  assert.equal(pool.calls.filter(call => call.method === 'execute').length, authSchemaStatements.length);
  assert.deepEqual(pool.calls.filter(call => call.method === 'query').map(call => call.sql), [
    'SELECT 1', 'SELECT 1 FROM members LIMIT 0', 'SELECT 1 FROM auth_sessions LIMIT 0',
  ]);
  assert.match(authSchemaStatements[0], /UNIQUE KEY uq_members_email/);
  assert.match(authSchemaStatements[1], /ON DELETE CASCADE/);
  const migration = readFileSync(new URL('../server/migrations/001_auth_mysql.sql', import.meta.url), 'utf8')
    .split(';').map(statement => statement.trim()).filter(Boolean);
  assert.deepEqual(migration, authSchemaStatements.map(statement => statement.trim()));
});

test('운영 기본값은 스키마를 변경하지 않고 기존 테이블만 확인', async () => {
  const pool = new FakePool();
  await new MySqlAuthRepository(pool).initialize();
  assert.equal(pool.calls.some(call => call.method === 'execute'), false);
  assert.deepEqual(pool.calls.filter(call => call.method === 'query').map(call => call.sql), [
    'SELECT 1', 'SELECT 1 FROM members LIMIT 0', 'SELECT 1 FROM auth_sessions LIMIT 0',
  ]);
});

test('MySQL 인증 저장소는 준비된 쿼리로 회원과 세션을 저장·조회', async () => {
  const pool = new FakePool();
  const repository = new MySqlAuthRepository(pool);
  pool.rows = [storedRow];
  const user = await repository.findUserByEmail('player@example.com');
  assert.equal(user.name, '장기인');
  assert.equal(user.createdAt, '2026-09-29T00:00:00.000Z');
  await repository.createUser(user);
  assert.ok(pool.calls.at(-1).sql.includes('VALUES (?, ?, ?, ?, ?, ?, ?, ?)'));
  pool.rows = [{ ...storedRow, expires_at: new Date('2026-10-06T00:00:00.000Z') }];
  const session = await repository.findSession('token-hash', Date.parse('2026-09-29T00:00:00.000Z'));
  assert.equal(session.user.email, 'player@example.com');
  assert.equal(session.expiresAt, Date.parse('2026-10-06T00:00:00.000Z'));
  await repository.createSession({ tokenHash: 'token-hash', userId: user.id, expiresAt: session.expiresAt, createdAt: Date.now() });
  await repository.deleteSession('token-hash');
  await repository.deleteExpiredSessions(Date.now());
  assert.ok(pool.calls.slice(-3).every(call => call.sql.includes('?')));
});

test('MySQL 연결 문자열은 mysql 스키마와 데이터베이스를 요구', () => {
  for (const value of ['https://localhost/db', 'mysql://localhost', 'invalid']) {
    assert.throws(() => MySqlAuthRepository.fromUrl(value), /MYSQL_URL|Invalid URL/);
  }
});
