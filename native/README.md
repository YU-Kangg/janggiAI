# Android 기기 엔진 연결 기반

Fairy-Stockfish를 Godot GDExtension 공유 라이브러리로 빌드하는 개발용 기반입니다.
**앱 추천 버튼과 APK에는 아직 연결하지 않았습니다.** 기본 대국은 기존 서버를 사용합니다.

## 고정 소스와 준비

프로젝트 루트의 `.local` 아래에 다음 소스를 준비합니다. 엔진 소스는 수정하지 않습니다.

| 경로 | 소스 / 버전 |
| --- | --- |
| `.local/fairy-source` | [Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish/tree/226c7f18c854372d5612be2a7d7f14449ae5a239), `226c7f18c854372d5612be2a7d7f14449ae5a239` |
| `.local/godot-cpp` | [godot-cpp](https://github.com/godotengine/godot-cpp/tree/b0e3b1e4b78a606f48d162898afb5eeda533d2a9), `b0e3b1e4b78a606f48d162898afb5eeda533d2a9` (4.4), 서브모듈 포함 |
| `.local/android-ndk-r28b` | Google Android NDK r28b Windows, `28.1.13356709` |
| `.local/python/python.exe` | Python 3.12.10 + SCons 4.9.1 |

Git clone 후 해당 커밋을 checkout하고 godot-cpp에서는 `git submodule update --init --recursive`를 실행합니다.
Python embeddable 배포판을 사용할 경우 `python312._pth`에 `Lib/site-packages`와 `import site`를 추가한 뒤 pip로 SCons를 설치합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-native.ps1
# ARM64만 확인
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-native.ps1 -Architectures arm64
```

스크립트는 소스 커밋·수정 여부·NDK 버전과 공유 라이브러리 진입점을 확인합니다.
출력은 Git에서 제외된 `godot/native/bin/libjanggi.android.<arch>.so`입니다.
16KiB 페이지 정렬과 정적 C++ 런타임을 사용합니다. 빌드 성공이 실제 Android 로딩·동작 검증을 의미하지는 않습니다.

## 연결 계약

등록 클래스는 `JanggiNative`(RefCounted)입니다. `janggi.gdextension.example`은 다음 앱 통합 단계의 설정 예제입니다.
Android 전용 확장을 데스크톱에서 자동 로딩하지 않도록 현재 프로젝트에 활성화하지 않습니다.

1. 앱에서 엔진 인스턴스 하나를 유지하고 `prepare()` 성공 후 작업 스레드에서 `analyze(initial_fen, moves)`를 한 번 호출합니다.
2. 초기 차림 16종과 전체 기보를 전달합니다. 엔진이 기보를 합법 수로 재생하고 300ms 탐색합니다.
3. 반환 Dictionary에는 `move`, `fen`, `depth`, `elapsed_ms`, `source` 또는 `error`가 있습니다.
4. 메인 스레드에서 결과의 FEN·요청 당시 revision·현재 합법 수를 확인한 뒤 표시해야 합니다. 자동 착수하지 않습니다.
5. 취소·장면 변경·백그라운드 전환 시 `cancel()`하고 작업 스레드를 회수합니다. 준비 후 스레드 시작 실패 시에도 예약 해제가 필요하므로 앱 래퍼에서 반드시 처리해야 합니다.

고정 설정: `janggi`, 1스레드, Hash 16MiB, NNUE 비활성화. 로딩 시간은 300ms 탐색 예산에 포함되지 않습니다.
임의 FEN·불법 기보·종료 후 기보는 거부합니다. 앱 통합 시 서버 규칙 버전과의 결과 차이도 검증해야 합니다.

## 라이선스와 다음 단위

어댑터 `janggi_engine.cpp`는 GPL-3.0-or-later입니다. Fairy-Stockfish의 라이선스 원문은 고정 소스의 `Copying.txt`,
godot-cpp는 MIT(`LICENSE.md`)입니다. APK에 포함하는 단계에서 라이선스 고지와 정확한 대응 소스·빌드 자료 제공도 함께 연결합니다.

다음 작업: 예약 실패 복구를 포함한 Godot 스레드 래퍼, APK 패키징, 기기 추천 버튼, 취소·오래된 결과 차단,
휴대폰에서 실제 확장 로딩·추천 수 합법성·응답 시간 검증. NNUE와 완전 오프라인 대국은 후속 범위입니다.
