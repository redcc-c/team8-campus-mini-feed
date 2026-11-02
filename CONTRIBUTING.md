# 팀 협업 방법

1. 준비 PR이 병합된 뒤 main을 갱신한다. 병합 전에는 `codex/team-bootstrap`을 개발 시작점으로 사용한다.
2. 담당 작업용 브랜치를 만든다. 예: `feature/board-feed`, `feature/post-comments`, `feature/ondevice-correction`.
3. 작업 범위와 데이터 계약 변경 여부를 PR에 적는다. 공통 모델·저장소 계약을 바꾸면 다른 두 명에게 먼저 알린다.
4. `dart format`, `flutter analyze`, `flutter test`를 실행한다. Firebase 규칙 변경 시 `npm run test:emulators`도 실행한다.
5. 다른 팀원 한 명이 확인한 뒤 main에 합친다. 작성자가 통합과 검증을 한 사람에게 떠넘기지 않는다.

## 변경 기록

- 커밋 예: `feat: 댓글 입력 검증 추가`, `fix: 피드 정렬 오류 수정`, `docs: AI 실행 조건 기록`.
- 각자 담당 테스트와 보고서를 작성한다. AI를 사용했다면 `prompts_log.md`에 실제 요청과 수정·검증 결과를 추가한다.
- 관리자 키·개인 계정·실제 게시글·기기 식별 로그를 PR 설명이나 테스트 데이터에 넣지 않는다.
- 패키지 버전과 `pubspec.lock`, `package-lock.json` 변경 이유를 함께 적는다.

## 준비 PR의 범위

이번 PR은 실행 가능한 초기 앱, 공통 계약, 로컬 Firebase 연결, 기본 테스트와 문서를 준비한다. 실제 AI 모델·운영 프로젝트·관리자 기능은 후속 작업이다. 준비된 샘플 기능을 각 담당자가 이어받아 요구사항대로 완성한다.
