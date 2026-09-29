# 회원 인증 API

기본 주소는 `http://127.0.0.1:3000`입니다. 모든 요청과 응답은 JSON이며 인증 응답은 `Cache-Control: no-store`로 반환됩니다.

## 회원가입

`POST /api/auth/register`

```json
{
  "email": "player@example.com",
  "password": "8자 이상의 비밀번호",
  "name": "장기인"
}
```

성공 시 `201`과 공개 회원 정보를 반환합니다. 이메일은 소문자로 정규화되며 같은 이메일은 `409`로 거부합니다.

## 로그인

`POST /api/auth/login`

```json
{
  "email": "player@example.com",
  "password": "8자 이상의 비밀번호"
}
```

웹 클라이언트에는 `janggi_session` HttpOnly 쿠키를 설정하고 본문에는 회원과 만료 시각만 반환합니다. Android 앱은 `X-Janggi-Client: mobile` 헤더를 보내면 본문에 Bearer 토큰도 받습니다. 모바일 토큰은 Android Keystore 기반 안전 저장소에 보관해야 합니다.

## 현재 세션

`GET /api/auth/session`

웹은 세션 쿠키를 자동 전송합니다. 모바일은 다음 헤더를 사용합니다.

```text
Authorization: Bearer <token>
```

유효한 세션은 회원 정보와 만료 시각을 반환하고, 없거나 만료된 세션은 `401`을 반환합니다.

## 로그아웃

`POST /api/auth/logout`

쿠키 또는 Bearer 토큰으로 식별한 서버 세션을 폐기하고 쿠키를 삭제합니다. 이미 만료된 세션도 `200`으로 처리합니다.

## MySQL 연결

회원과 세션은 MySQL의 `members`, `auth_sessions` 테이블에 저장합니다. SQL 원본은 `server/migrations/001_auth_mysql.sql`입니다.

```text
MYSQL_URL=mysql://janggi_app:password@127.0.0.1:3306/janggi
```

로컬 최초 설정에서는 `MYSQL_AUTO_MIGRATE=true`를 함께 지정하면 테이블을 자동 생성합니다. 운영 환경은 배포 전에 별도 마이그레이션 계정으로 SQL을 실행하고 애플리케이션에서는 이 값을 사용하지 않습니다. 평상시 서버는 연결과 두 테이블의 존재만 확인하므로 애플리케이션 계정에는 회원·세션 테이블의 `SELECT`, `INSERT`, `DELETE` 권한만 부여할 수 있습니다.

TLS가 필요한 MySQL 서비스는 연결 문자열 끝에 `?ssl=true`를 지정합니다. 운영용 DB 비밀번호는 `.env`를 Git에 추가하지 말고 배포 환경의 비밀 저장소에서 주입해야 합니다.

## 현재 운영 제약

- `MYSQL_URL`이 설정된 서버에서는 로그인 세션이 서버 재시작 후에도 유지됩니다.
- 개발 모드에서 `MYSQL_URL`이 없으면 회원·세션은 메모리에만 저장합니다. 운영 모드는 연결 문자열 없이는 시작되지 않습니다.
- 로컬 HTTP 개발에서는 Secure 쿠키를 사용하지 않습니다. `NODE_ENV=production`에서는 Secure 속성을 설정하므로 HTTPS 앞에서 실행해야 합니다.
- 이메일 인증, 비밀번호 재설정, 탈퇴와 개인정보 처리 흐름은 아직 구현하지 않았습니다.

비밀번호 저장과 세션 정책은 [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)와 [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)를 기준으로 구성했습니다.
