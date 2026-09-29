import { createHash, randomBytes, randomUUID, scrypt as scryptCallback, scryptSync, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback);
const SCRYPT_OPTIONS = { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const dummySalt = Buffer.from('janggi-login-dummy-salt');
const DUMMY_PASSWORD = {
  algorithm: 'scrypt', salt: dummySalt.toString('base64'),
  hash: scryptSync('invalid-login-password', dummySalt, 32, SCRYPT_OPTIONS).toString('base64'),
};
const fail = (message, status) => Object.assign(new Error(message), { status });

const normalizeEmail = value => typeof value === 'string' ? value.trim().toLowerCase() : '';
const validEmail = value => typeof value === 'string' && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(value);
const publicUser = user => ({ id: user.id, email: user.email, name: user.name, role: user.role, createdAt: user.createdAt });
const tokenDigest = token => createHash('sha256').update(token).digest('base64url');

export class AuthService {
  constructor({ storage = null, now = () => Date.now() } = {}) {
    this.storage = storage;
    this.now = now;
    this.sessions = new Map();
    this.mutation = Promise.resolve();
    const saved = storage?.load();
    if (saved && (saved.version !== 1 || !Array.isArray(saved.users))) throw new Error('저장된 회원 정보 형식이 올바르지 않습니다.');
    this.users = saved?.users ?? [];
    for (const user of this.users) this.validateStoredUser(user);
  }

  validateStoredUser(user) {
    const salt = typeof user?.password?.salt === 'string' ? Buffer.from(user.password.salt, 'base64') : Buffer.alloc(0);
    const hash = typeof user?.password?.hash === 'string' ? Buffer.from(user.password.hash, 'base64') : Buffer.alloc(0);
    if (!user || typeof user.id !== 'string' || !validEmail(user.email) || typeof user.name !== 'string'
      || user.name.length < 2 || user.name.length > 20
      || user.role !== 'user' || user.password?.algorithm !== 'scrypt' || typeof user.password.salt !== 'string'
      || typeof user.password.hash !== 'string' || salt.length !== 16 || hash.length !== 32
      || typeof user.createdAt !== 'string' || !Number.isFinite(Date.parse(user.createdAt))) {
      throw new Error('저장된 회원 정보 형식이 올바르지 않습니다.');
    }
  }

  validateInput({ email, password, name }, registering = false) {
    const normalizedEmail = normalizeEmail(email);
    if (!validEmail(normalizedEmail)) throw fail('올바른 이메일 주소를 입력하세요.', 400);
    if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
      throw fail('비밀번호는 8~128자로 입력하세요.', 400);
    }
    let normalizedName;
    if (registering) {
      normalizedName = typeof name === 'string' ? name.trim() : '';
      if (normalizedName.length < 2 || normalizedName.length > 20 || /[\u0000-\u001f\u007f]/u.test(normalizedName)) {
        throw fail('이름은 2~20자로 입력하세요.', 400);
      }
    }
    return { email: normalizedEmail, password, name: normalizedName };
  }

  async passwordRecord(password) {
    const salt = randomBytes(16);
    const hash = await scrypt(password, salt, 32, SCRYPT_OPTIONS);
    return { algorithm: 'scrypt', salt: salt.toString('base64'), hash: hash.toString('base64') };
  }

  async passwordMatches(password, record) {
    const salt = Buffer.from(record.salt, 'base64');
    const expected = Buffer.from(record.hash, 'base64');
    const actual = await scrypt(password, salt, expected.length, SCRYPT_OPTIONS);
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  }

  async register(input) {
    const value = this.validateInput(input, true);
    const password = await this.passwordRecord(value.password);
    return this.enqueue(async () => {
      if (this.users.some(user => user.email === value.email)) throw fail('이미 가입된 이메일입니다.', 409);
      const user = {
        id: randomUUID(), email: value.email, name: value.name, role: 'user', password,
        createdAt: new Date(this.now()).toISOString(),
      };
      const next = [...this.users, user];
      this.storage?.save({ version: 1, users: next });
      this.users = next;
      return publicUser(user);
    });
  }

  async login(input) {
    const value = this.validateInput(input, false);
    const user = this.users.find(candidate => candidate.email === value.email);
    const fallback = user?.password ?? DUMMY_PASSWORD;
    const matches = await this.passwordMatches(value.password, fallback);
    if (!user || !matches) throw fail('이메일 또는 비밀번호가 올바르지 않습니다.', 401);
    return this.createSession(user);
  }

  createSession(user) {
    this.removeExpiredSessions();
    const token = randomBytes(32).toString('base64url');
    const expiresAt = this.now() + SESSION_TTL_MS;
    this.sessions.set(tokenDigest(token), { userId: user.id, expiresAt });
    return { token, expiresAt: new Date(expiresAt).toISOString(), user: publicUser(user) };
  }

  session(token) {
    if (typeof token !== 'string' || !token) return null;
    const key = tokenDigest(token);
    const session = this.sessions.get(key);
    if (!session) return null;
    if (session.expiresAt <= this.now()) {
      this.sessions.delete(key);
      return null;
    }
    const user = this.users.find(candidate => candidate.id === session.userId);
    if (!user) {
      this.sessions.delete(key);
      return null;
    }
    return { user: publicUser(user), expiresAt: new Date(session.expiresAt).toISOString() };
  }

  logout(token) {
    if (typeof token === 'string' && token) this.sessions.delete(tokenDigest(token));
  }

  removeExpiredSessions() {
    const now = this.now();
    for (const [key, session] of this.sessions) if (session.expiresAt <= now) this.sessions.delete(key);
  }

  enqueue(operation) {
    const result = this.mutation.then(operation);
    this.mutation = result.catch(() => {});
    return result;
  }
}

export const sessionCookie = (token, { secure = false, clear = false } = {}) => [
  `janggi_session=${clear ? '' : encodeURIComponent(token)}`,
  'Path=/', 'HttpOnly', 'SameSite=Lax',
  ...(secure ? ['Secure'] : []),
  clear ? 'Max-Age=0' : `Max-Age=${Math.floor(SESSION_TTL_MS / 1000)}`,
].join('; ');

export function requestToken(req) {
  const authorization = req.headers.authorization;
  if (typeof authorization === 'string' && authorization.startsWith('Bearer ')) return authorization.slice(7).trim();
  const cookies = typeof req.headers.cookie === 'string' ? req.headers.cookie.split(';') : [];
  for (const cookie of cookies) {
    const [name, ...parts] = cookie.trim().split('=');
    if (name === 'janggi_session') {
      try { return decodeURIComponent(parts.join('=')); }
      catch { return ''; }
    }
  }
  return '';
}
