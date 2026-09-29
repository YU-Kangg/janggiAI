import mysql from 'mysql2/promise';
import { readFileSync } from 'node:fs';

export const authSchemaStatements = readFileSync(new URL('./migrations/001_auth_mysql.sql', import.meta.url), 'utf8')
  .split(';').map(statement => statement.trim()).filter(Boolean);

const toIso = value => value instanceof Date ? value.toISOString() : new Date(`${value}Z`).toISOString();
const mapUser = row => row ? ({
  id: row.id, email: row.email, name: row.display_name, role: row.role,
  password: { algorithm: row.password_algorithm, salt: row.password_salt, hash: row.password_hash },
  createdAt: toIso(row.created_at),
}) : null;

export class MySqlAuthRepository {
  constructor(pool, { autoMigrate = false } = {}) {
    this.pool = pool;
    this.autoMigrate = autoMigrate;
  }

  static fromUrl(connectionUrl, options = {}) {
    const url = new URL(connectionUrl);
    if (!['mysql:', 'mysql2:'].includes(url.protocol) || !url.hostname || !url.pathname.slice(1)) {
      throw new Error('MYSQL_URL 형식이 올바르지 않습니다.');
    }
    const ssl = url.searchParams.get('ssl') === 'true' ? {} : undefined;
    return new MySqlAuthRepository(mysql.createPool({
      host: url.hostname, port: Number(url.port || 3306), user: decodeURIComponent(url.username),
      password: decodeURIComponent(url.password), database: decodeURIComponent(url.pathname.slice(1)),
      waitForConnections: true, connectionLimit: 10, maxIdle: 10, idleTimeout: 60000,
      enableKeepAlive: true, timezone: 'Z', ssl,
    }), options);
  }

  async initialize() {
    if (this.autoMigrate) for (const statement of authSchemaStatements) await this.pool.execute(statement);
    await this.pool.query('SELECT 1');
    await this.pool.query('SELECT 1 FROM members LIMIT 0');
    await this.pool.query('SELECT 1 FROM auth_sessions LIMIT 0');
  }

  async findUserByEmail(email) {
    const [rows] = await this.pool.execute(
      `SELECT id, email, display_name, role, password_algorithm, password_salt, password_hash, created_at
       FROM members WHERE email = ? LIMIT 1`, [email],
    );
    return mapUser(rows[0]);
  }

  async createUser(user) {
    await this.pool.execute(
      `INSERT INTO members
       (id, email, display_name, role, password_algorithm, password_salt, password_hash, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [user.id, user.email, user.name, user.role, user.password.algorithm, user.password.salt, user.password.hash, new Date(user.createdAt)],
    );
  }

  async createSession(session) {
    await this.pool.execute(
      'INSERT INTO auth_sessions (token_hash, member_id, expires_at, created_at) VALUES (?, ?, ?, ?)',
      [session.tokenHash, session.userId, new Date(session.expiresAt), new Date(session.createdAt)],
    );
  }

  async findSession(tokenHash, now) {
    const [rows] = await this.pool.execute(
      `SELECT s.expires_at, m.id, m.email, m.display_name, m.role,
              m.password_algorithm, m.password_salt, m.password_hash, m.created_at
       FROM auth_sessions s JOIN members m ON m.id = s.member_id
       WHERE s.token_hash = ? AND s.expires_at > ? LIMIT 1`,
      [tokenHash, new Date(now)],
    );
    return rows[0] ? { user: mapUser(rows[0]), expiresAt: new Date(rows[0].expires_at).getTime() } : null;
  }

  async deleteSession(tokenHash) { await this.pool.execute('DELETE FROM auth_sessions WHERE token_hash = ?', [tokenHash]); }
  async deleteExpiredSessions(now) { await this.pool.execute('DELETE FROM auth_sessions WHERE expires_at <= ?', [new Date(now)]); }
  async close() { await this.pool.end(); }
}
