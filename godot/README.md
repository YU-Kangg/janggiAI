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
APK 내보내기를 시도했지만 **Android SDK와 Godot 4.7.2 Android export templates가 없어 실패**했습니다.
현재 PC의 Java 17은 확인했습니다. APK 생성·휴대폰 설치·실제 터치 테스트는 아직 하지 않았습니다.

다음 단위에서 SDK/동일 버전 export templates를 설치하고 Godot Editor Settings에 SDK/JDK 경로를 지정합니다.
설치 절차는 [공식 Android 내보내기 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)를 따릅니다.
그 뒤 `build/` 폴더를 만들고 다음 명령으로 디버그 APK를 생성합니다.

```text
godot --headless --path godot --export-debug "Android Debug" build/janggi-debug.apk
```

USB 디버깅을 허용한 Android 기기에서는 `adb reverse tcp:3000 tcp:3000`으로 PC 서버를 연결할 수 있습니다.
이 경우 앱 주소는 `http://127.0.0.1:3000`을 유지합니다. reverse가 없으면 휴대폰의 localhost는 PC를 가리키지 않습니다.
초기 검증은 USB 방식으로 진행하며 서버의 localhost 바인딩은 유지합니다.
릴리스용 HTTPS 서버·기기 내 AI·기보 복기 화면·고양이 연출·스토어 서명은 후속 작업입니다.
