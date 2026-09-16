# 고양이 장기: Godot 4 전환 검토

검토일: 2026-09-16. 현재 구현 및 Godot 공식 문서 기준. 실제 Godot 이식·빌드 검증은 아직 하지 않음.

## 결론

고양이 캐릭터의 이동·잡기·표정·카메라 연출이 중요한 설치형 게임이라면 Godot 4를 추천한다.
현재 구조와의 개념적 충돌은 적지만, 화면 코드와 기기 내 엔진 연결은 플랫폼에 맞춰 새로 작성해야 한다.
가장 작은 시작은 Godot 클라이언트를 기존 Node HTTP API에 연결하는 것이다.
완전 오프라인 네이티브 제품으로의 전환은 그 다음 별도 작업이다.
이번 검토로 기존 웹 개발 계획을 확정 변경하거나 구현 코드를 이식하지는 않는다.

## 현재 작업의 재사용 범위

| 현재 구현 | Godot 화면 + 기존 Node 서버 | Node 없는 네이티브 앱 |
| --- | --- | --- |
| public/index.html, style.css, app.js | 화면·입력·상태 표시 재작성 | 동일 |
| server/rules.js, ffish-es6 | 그대로 서버에서 사용 | JS/WASM 바인딩 직접 사용 불가. 네이티브 규칙 연결 필요 |
| server/game.js | 차례·종료·무르기·AI 취소 정책 재사용 | 정책·테스트 사례 유지, 실행 코드는 이식 |
| server/engine.js, 장기 NNUE 실행 파일 | 그대로 재사용 | Windows 엔진 재사용 가능, 프로세스 통신 어댑터 재작성 |
| public/analysis-worker.js, local-analysis.js | 브라우저 밖에서는 직접 사용 불가. 초기에는 서버 추천 사용 | 네이티브 엔진으로 대체 |
| JSON 기보, 초기 FEN, UCI 착수열 | 그대로 재사용 | 형식 유지 가능. 파일 접근·저장 위치는 이식 |
| 서버 테스트 | 그대로 사용 | 동일 사례를 새 구현에도 적용 |
| Playwright 화면 테스트 | 기존 웹 전용 | Godot 화면·입력 검증 새로 필요 |

기존 성과는 규칙·기보·엔진 프로토콜·동시성 처리의 검증 자료로 남는다. 코드 재사용률을 숫자로 단정하지 않는다.

## 충돌이 큰 세 지점

1. **브라우저 종속 코드:** DOM/CSS/Worker를 Godot 네이티브에서 직접 실행할 수 없다.
   Godot 웹 빌드라면 JavaScriptBridge로 기존 분석을 연결하는 방법이 있지만 별도 연결 코드가 필요하다.
2. **합법 수·종료 판정:** 추천 엔진만 붙여서는 현재 ffish가 맡는 반복·빅장·종료 판정을 대체했다고 볼 수 없다.
   완전 오프라인 버전에서는 규칙 API도 제공해야 하며 FEN뿐 아니라 전체 이력을 유지한다.
3. **플랫폼별 엔진 배포:** Windows의 exe 방식은 모바일에 그대로 옮길 수 없다.
   Android/iOS는 플랫폼별 네이티브 라이브러리 연결·빌드와 메모리·수명주기 검증을 별도로 잡는다.

## 추천 구조와 작은 전환 순서

첫 검증 구조: `Godot 화면 → HTTP JSON → 기존 Game/규칙/저장/NNUE`.
Godot의 HTTPRequest로 현재 API를 호출하면 된다. 이 단계는 Node가 실행 중이어야 한다.
개발 PC에서 함께 실행하면 외부 인터넷 없이 시험할 수 있지만, Godot 단독 실행 파일은 아니다.

1. `godot/` 폴더에 작은 프로젝트 추가. 장기판 표시·선택·합법 수·착수만 기존 API로 연결.
2. AI 응수·무르기·기보 복기 연결. 현재 JSON 기보와 결과가 같은지 비교.
3. 고양이 임시 캐릭터 하나에 이동·잡기 연출 적용. 2D/3D 방향과 제작량 판단.
4. Windows 우선이라면 로컬 Fairy-Stockfish UCI 연결 검증 및 규칙 연결 방식 결정.
5. Node를 제거할지 동봉할지 결정하고 저장·종료·배포 검증. 모바일은 별도 어댑터 구현.

화면 연출과 판 상태를 분리한다. 착수 결과는 즉시 확정하고 애니메이션은 결과를 표현한다.
예를 들어 고양이가 걸어가는 도중 무르기하면 애니메이션을 취소하고 해당 revision의 판을 다시 표시한다.
기본 janggi 규칙을 유지하면 고양이 외형은 엔진과 충돌하지 않는다. 특수 능력·새 이동 규칙을 넣으면 별도 변형 규칙 작업이다.

## 플랫폼 판단

- **Windows/Steam 우선:** Godot 도입에 적합. 현재 Windows NNUE 바이너리 재사용 여지가 크다.
- **모바일 설치형 우선:** Godot는 화면을 담당할 수 있으나 기기 내 장기 엔진 통합이 주요 공수다.
- **브라우저 분석 서비스 우선:** 현재 웹 구현을 유지하는 편이 단순하다. Godot 웹을 추가하면 렌더링·엔진의 로딩 및 메모리를 함께 측정해야 한다.
- **Steam·모바일·웹 동시 출시:** 첫 단계 목표로 잡지 않고 우선 플랫폼 하나에서 검증한다.

고양이 모델·리깅·애니메이션·효과음은 엔진 전환만으로 생기지 않는다. 별도 제작 범위로 계획한다.
기존 엔진 라이선스 검토는 THIRD_PARTY.md를 이어 사용하며 Godot 채택 자체가 이를 해결하지는 않는다.

## 확인한 자료

- [Cat Chess Steam 페이지](https://store.steampowered.com/app/4163030/Cat_Chess/): 캐릭터 애니메이션과 온·오프라인 게임 방향 참고. 해당 게임이 Godot로 제작됐다고 확인한 것은 아님.
- [Godot 애니메이션 기능](https://docs.godotengine.org/en/stable/tutorials/animation/introduction.html): 캐릭터 연출 도구.
- [HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html): 기존 JSON API 연결.
- [OS / execute_with_pipe](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-execute-with-pipe): 외부 프로세스 입출력. 실제 대상 버전·플랫폼 검증 필요.
- [JavaScriptBridge](https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html): 웹 전용 JavaScript 연결.
- [웹 내보내기](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): 스레드와 SharedArrayBuffer, 웹용 확장 빌드 제약.
