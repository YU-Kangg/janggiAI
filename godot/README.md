# Godot 고양이 장기 시제품

Godot 4.7.2 / GDScript / Compatibility 렌더러. 현재는 고양이 아트 대신 한글 기물 버튼을 사용합니다.
기본 janggi 규칙·AI·저장은 기존 Node 서버에서 처리합니다. 독립 오프라인 앱은 아직 아닙니다.

## PC에서 실행

1. 프로젝트 루트에서 `npm ci`, `node server/index.js`로 서버를 실행합니다.
2. Godot에서 이 폴더의 `project.godot`를 열고 F6 또는 F5로 실행합니다.
3. 기본 주소 `http://127.0.0.1:3000`으로 기존 대국을 확인합니다.
4. 초/한을 선택하고 **새 AI 대국**을 누릅니다. 기존 공유 기보를 교체하기 전에 확인 창이 나옵니다.
5. 내 기물과 초록색 도착점을 순서대로 누릅니다. AI는 서버에서 자동 응수합니다.

이 PC에는 `.local/godot/Godot_v4.7.2-stable_win64.exe`를 준비했습니다.
루트에서 다음 명령으로도 실행할 수 있습니다.

```powershell
& .local/godot/Godot_v4.7.2-stable_win64.exe --path godot
```

서버 주소는 화면에서 입력하거나 `-- --server=http://127.0.0.1:3000` 실행 인자로 지정할 수 있습니다.
웹과 Godot는 현재 한 대국을 공유합니다. 웹의 새 대국·무르기도 Godot에 반영됩니다.
한을 선택하면 판이 뒤집힙니다. 한수쉼·무르기·AI 취소·재개를 지원합니다.
서버 끊김·잘못된 수·오래된 요청은 오류를 표시합니다. 0.5초 간격으로 상태를 조회합니다.

## 자동 검증

루트에서 `node --test test/godot.test.js`를 실행합니다.
Godot 실행 파일은 위 로컬 경로 또는 `JANGGI_GODOT_PATH` 환경 변수에서 찾습니다.
실행 파일이 없으면 이 테스트는 skip됩니다.
테스트는 별도 임시 서버를 사용하므로 현재 저장 대국에 영향을 주지 않습니다.
실제 Godot 장면을 headless로 실행해 기물 선택·착수·초/한 NNUE 응수·무르기·불법 수·연결 실패를 확인합니다.
실제 화면 터치·렌더링과 휴대폰 호환성 검증을 대신하지는 않습니다.

## Android 진행 상태

`Android Debug` 내보내기 프리셋을 추가했습니다. 인터넷 권한과 arm64/x86_64 아키텍처를 설정했습니다.
**디버그 APK 생성과 서명 검증을 완료했습니다.** 산출물: `godot/build/janggi-debug.apk` (약 57MB).
Android 7.0/API 24 이상, ARM64 또는 x86_64 대상입니다. target SDK는 템플릿 기준 36입니다.
현재 연결된 실기기가 없어 휴대폰 설치·실제 터치·서버 통신 테스트는 아직 하지 않았습니다.

프로젝트 루트 PowerShell에서 다시 빌드합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-android.ps1
```

이 PC의 개발 도구는 `.local/`에 두었습니다. Git에 도구·APK·서명 키는 포함하지 않습니다.
- `.local/godot/`: Godot 4.7.2, `_sc_` 파일로 자체 editor_data 설정 사용.
- `.local/android-sdk/platform-tools/`: 공식 platform-tools 37.0.1.
- `.local/android-sdk/build-tools/35.0.1/`: 공식 Build-Tools 35.0.1.
- `.local/android-templates/`: 공식 4.7.2 export templates에서 추출한 android_debug.apk / android_release.apk.
- Java 17은 `JAVA_HOME` 또는 PATH의 java.exe에서 찾습니다. `-JavaSdkPath`로 지정할 수도 있습니다.

일반 디버그 APK는 미리 빌드된 템플릿으로 생성하므로 이번에는 NDK/Gradle 소스 빌드 도구를 설치하지 않았습니다.
Godot가 target SDK 36과 Build-Tools 35.0.1 버전 차이 안내를 출력하지만 APK 생성·서명 검사는 통과했습니다.
스토어 AAB·플러그인·네이티브 라이브러리 빌드 환경은 별도 준비가 필요합니다.
도구를 새로 준비할 때는 [Godot 공식 Android 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)와 [4.7.2 배포](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)를 참고하세요.

## 휴대폰에 설치하고 실행

1. PC 장기 서버를 실행합니다: `node server/index.js`.
2. Android 개발자 옵션에서 USB 디버깅을 켜고 케이블을 연결한 뒤, 휴대폰에서 PC 연결을 허용합니다.
3. 프로젝트 루트에서 다음 명령을 실행합니다. APK 설치 → USB 포트 연결 → 앱 실행을 수행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-android.ps1
```

여러 기기가 연결되어 있으면 `-Serial 기기번호`를 지정합니다. 연결·인증된 기기만 대상으로 합니다.
기존 앱과 서명이 달라 설치가 실패하면 스크립트는 중단하며 기존 앱을 자동 삭제하지 않습니다.
화면 표시·터치 착수·초/한 AI 응수·무르기·USB 분리 후 재연결을 실제 기기에서 확인해야 합니다.

USB 디버깅을 허용한 Android 기기에서는 `adb reverse tcp:3000 tcp:3000`으로 PC 서버를 연결할 수 있습니다.
이 경우 앱 주소는 `http://127.0.0.1:3000`을 유지합니다. reverse가 없으면 휴대폰의 localhost는 PC를 가리키지 않습니다.
초기 검증은 USB 방식으로 진행하며 서버의 localhost 바인딩은 유지합니다.
릴리스용 HTTPS 서버·기기 내 AI·기보 복기 화면·고양이 연출·스토어 서명은 후속 작업입니다.
