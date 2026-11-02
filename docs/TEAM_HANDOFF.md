# 세 명이 개발을 시작하는 방법

공통 첫 확인은 저장소 복제 → `flutter pub get` → `flutter run`이다. 기본값인 체험 모드는 Firebase 계정이 없어도 실행된다. 초대 수락 여부는 각자 GitHub에서 확인한다.

| 담당 | 먼저 볼 파일 | 첫 작업 | 완료를 확인할 방법 |
| --- | --- | --- | --- |
| redcc-c | `lib/core/bootstrap.dart`, `lib/features/boards/`, `lib/features/feed/`, `firestore.rules` | 게시판·피드 UI와 익명 인증 흐름을 설계서에 맞추고 신고 처리 연결 확인 | 게시판별 피드 분리, 최신순, 두 기기 동기화 및 신고 데이터 검증 |
| GhostRamen918 | `lib/features/posts/`, `lib/data/community_repository.dart`, `lib/data/firebase_repository.dart` | 기본 글쓰기·상세·댓글·좋아요를 이어받아 오류·중복 요청 처리 보완 | 공백/경계값/연속 탭/저장 지연/실패 입력 보존 테스트 |
| Ryoon0504 | `lib/features/ai/correction_service.dart`, `lib/features/posts/compose_screen.dart` | 지원 기기에서 모델의 최소 문장 교정부터 확인하고 `CorrectionService` 구현 | 외부 서버 없이 교정, 선택 적용/되돌리기, 실패 원문 유지 |

## 함께 먼저 합의할 것

- `docs/DATA_CONTRACT.md`의 ID·필드명·글자 수·시간 형식을 사용한다.
- 글자 수는 Unicode 코드 포인트, AI 입력 제한은 선택 모델 토큰 수이다. 둘을 같은 값으로 계산하지 않는다.
- 실제 Firebase 테스트 프로젝트는 공동으로 정한다. 이 저장소는 현재 Emulator만 자동 연결한다.
- 게시판 생성·성장·이미지·알림은 아직 구현되지 않았다. 범위를 추가할 때 담당자와 테스트를 함께 정한다.
- 첫 모델 실행 검증 후 AI 난도와 각자 소요 시간을 보고 작업량을 다시 조정한다.

## AI 연결 시 준수할 계약

`isAvailable`은 해당 기기에서 모델을 사용할 수 있을 때만 true로 반환한다. `check(text)`는 입력 스냅샷과 제안 목록을 반환한다. 제안 범위는 원문 Dart UTF-16 인덱스의 시작 포함·끝 제외 범위이며 서로 다른 원문의 오프셋을 섞지 않는다. 화면은 검사 이후 원문이 바뀌면 결과를 적용하지 않는다.

256토큰 미만 제약에 맞춘 실제 토크나이저, 문장·구절 분할, 실패 구간 원문 보존, 결과 병합은 AI 담당 구현 범위다. 임의 글자 수로 토큰 수를 대신하거나 예제 문장을 실제 AI 출력이라고 기록하지 않는다.

## 공통 책임

각자 기능 테스트·담당 보고서·AI 활용 기록을 작성한다. PR은 다른 한 명이 검토한다. 모든 오류 해결과 최종 통합을 팀장 한 사람의 고정 업무로 두지 않는다.
