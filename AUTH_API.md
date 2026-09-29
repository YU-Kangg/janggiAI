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

## 현재 운영 제약

- 로그인 세션은 서버 재시작 시 모두 만료됩니다.
- 로컬 HTTP 개발에서는 Secure 쿠키를 사용하지 않습니다. `NODE_ENV=production`에서는 Secure 속성을 설정하므로 HTTPS 앞에서 실행해야 합니다.
- 회원 정보는 개발용 JSON 파일에 저장합니다. 외부 서비스 전에는 운영 DB와 마이그레이션이 필요합니다.
- 이메일 인증, 비밀번호 재설정, 탈퇴와 개인정보 처리 흐름은 아직 구현하지 않았습니다.

비밀번호 저장과 세션 정책은 [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)와 [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)를 기준으로 구성했습니다.
