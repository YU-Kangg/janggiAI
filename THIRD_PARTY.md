# 외부 소프트웨어 기록

## Fairy-Stockfish / 장기 NNUE

- 저작자: Fabian Fichter 및 Fairy-Stockfish 기여자.
- 라이선스: GPLv3. [본문](https://github.com/fairy-stockfish/Fairy-Stockfish/blob/master/Copying.txt).
- 배포 태그: [janggi-9991472750de-new](https://github.com/fairy-stockfish/Fairy-Stockfish-NNUE/releases/tag/janggi-9991472750de-new).
- [배포 소스·평가망·빌드 자료](https://github.com/fairy-stockfish/Fairy-Stockfish-NNUE/tree/janggi-9991472750de-new).
- 엔진 소스 서브모듈: [a0b277d7abfe6094bd44da4b113b00a94f0325a1](https://github.com/fairy-stockfish/Fairy-Stockfish/tree/a0b277d7abfe6094bd44da4b113b00a94f0325a1).
- 평가망: `janggi-9991472750de.nnue` (위 배포에 포함).
- 실행 파일은 로컬 개발용 `.local` 폴더에 보관하며 이 프로젝트의 소스로 복사하거나 수정하지 않았습니다.

이 기록만으로 외부 배포 준비가 완료된 것은 아닙니다. 앱 내장 또는 WASM 배포 시 정확한 대응 소스,
변경분, 빌드 자료와 라이선스 고지를 제공하고 앱과 엔진의 결합 범위를 검토해야 합니다.

## ffish-es6 0.7.10

- Fairy-Stockfish 공식 WebAssembly 규칙 바인딩. 저작자: Fabian Fichter, Johannes Czech 및 기여자.
- 라이선스: GPL-3.0. [패키지](https://www.npmjs.com/package/ffish-es6/v/0.7.10), [소스 저장소](https://github.com/fairy-stockfish/Fairy-Stockfish).
- 설치 버전 및 무결성은 `package-lock.json`에 고정합니다. 런타임 식별 문자열은 `Fairy-Stockfish 230826 LB`입니다.
- 현재 서버에서만 로딩하며 브라우저로 WASM 복제본을 제공하지 않습니다.
- 서버 코드가 바인딩을 직접 링크하므로 해당 서버 코드를 배포할 경우 GPL 적용 범위도 검토해야 합니다.
