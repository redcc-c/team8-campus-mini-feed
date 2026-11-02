# 캠퍼스 소통 및 미니 피드 서비스

고급모바일프로그래밍 8조의 여러 게시판형 익명 커뮤니티 SNS입니다. Flutter 앱과 로컬 Firebase 개발 환경을 준비한 시작점이며, 온디바이스 AI 모델과 운영 서비스 연결은 후속 개발 범위입니다.

## 바로 시작

초기 준비 PR이 main에 합쳐지기 전에는 아래 브랜치를 사용합니다.

```powershell
git clone --branch codex/team-bootstrap https://github.com/redcc-c/team8-campus-mini-feed.git
cd team8-campus-mini-feed
flutter pub get
flutter run
```

PR 병합 후에는 일반 `git clone`으로 main을 받으면 됩니다. Android Studio에서는 저장소 루트 폴더를 Open하고 Flutter SDK 위치를 지정합니다. 현재 준비 PC의 SDK 위치는 `C:\Users\ckghd\flutter`이며, 다른 팀원은 자기 PC의 SDK 위치를 선택합니다.

## 개발 기준

| 항목 | 기준 |
| --- | --- |
| Flutter / Dart | Flutter 3.47.5 stable / Dart 3.13.4 |
| 기본 실행 대상 | Android 에뮬레이터 또는 실기기 |
| iOS | 프로젝트 틀 포함, iOS 15 이상 설정. Mac/Xcode에서 별도 빌드 검증 필요 |
| Firebase 테스트 도구 | Node.js 24 LTS, Java 21, `npm ci` |
| 실제 프로젝트 | 아직 연결하지 않음. 결제 설정과 원격 배포 없음 |

`pubspec.lock`, `package-lock.json`, Gradle wrapper를 함께 관리합니다. SDK와 패키지 버전 변경은 PR에서 합의합니다.

## 두 가지 실행 모드

### 체험 모드

`flutter run`의 기본값입니다. 서버와 계정 설정 없이 게시판 → 피드 → 글쓰기 → 상세 화면을 실행할 수 있습니다. 글·댓글·공감·신고는 앱 메모리에서만 처리되고 앱을 다시 시작하면 초기화됩니다. 다른 기기와 동기화되지 않습니다.

### Firebase Emulator 모드

아래 Windows PowerShell 명령을 저장소 루트에서 사용합니다. Mac/Linux에서는 `npm.cmd`, `npx.cmd` 대신 `npm`, `npx`를 사용합니다.

첫 번째 터미널:

```powershell
npm.cmd ci
npx.cmd firebase emulators:start --only auth,firestore --project demo-team8-campus
```

두 번째 터미널:

```powershell
npm.cmd run seed
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

앱이 실제 Firebase 익명 인증과 Firestore SDK를 로컬 에뮬레이터에 연결합니다. Android 에뮬레이터에서 호스트 PC 주소는 `10.0.2.2`입니다. 로컬 CLI의 Authentication은 9099, Firestore는 8080, Emulator UI는 4000 포트를 사용합니다. 상세 절차는 [Firebase 개발 안내](docs/FIREBASE.md)를 참고합니다.

`demo-team8-campus`는 라이브 리소스가 없는 데모 ID입니다. 기본 설정은 PC의 루프백 주소에만 바인딩하므로 다른 PC와 실기기를 연결하는 네트워크 설정은 별도 작업입니다.

`npm run seed`는 샘플 게시판 3개와 고정 환영 게시글만 갱신하며 기존 사용자 작성 글을 삭제하지 않습니다. Emulator를 종료하면 데이터는 사라집니다. 수동 로컬 데이터를 보관하려면 루트의 `emulator-data/`에 내보내세요.

## 준비된 기능과 남은 개발

| 준비된 시작점 | 팀원이 확장할 부분 |
| --- | --- |
| 게시판 선택·피드·글쓰기·상세 이동 | 최종 UI, 게시판 생성·성장, 필터·새로고침·페이지네이션 |
| 빈 글·500자 제한, 댓글 200자 제한 | 실제 네트워크 차단·지연·재시도 시나리오 |
| 데모 저장소와 Emulator 저장소 | 실제 테스트 Firebase 프로젝트 등록·연결 |
| 기본 댓글·공감·신고 연결 | 동시 요청·중복 요청·여러 기기 검증과 관리자 처리 |
| AI 서비스 계약과 적용·되돌리기 연결부 | 실제 기기 모델 연결, 토큰 제한 대응, 오프라인·성능 측정 |

AI 모델은 아직 연결하지 않았습니다. 기본 앱에서 교정 버튼은 비활성이고 그 사유를 표시합니다. 교정 결과를 임의로 만들어 보여주거나 작성 내용을 클라우드 AI에 전송하지 않습니다.

화면은 초기 개발용 공통 틀이며 기존 UI 설계서의 최종 디자인을 재현한 완료본은 아닙니다. 이미지 첨부·알림·게시판 성장·관리자 화면은 구현하지 않았습니다.

## 검증 명령

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
npm.cmd run test:emulators
flutter build apk --debug
```

규칙 테스트는 로컬 Firestore 데이터를 초기화합니다. 수동 앱 테스트와 동시에 실행하지 말고 별도 테스트 세션에서 실행합니다.

Android 장치 ID를 `flutter devices`로 확인한 뒤 실행합니다.

```powershell
flutter test integration_test/demo_flow_test.dart -d emulator-5554
# Emulator가 켜져 있고 npm run seed를 실행한 상태에서:
flutter test integration_test/firebase_flow_test.dart -d emulator-5554 --dart-define=USE_FIREBASE_EMULATORS=true
```

[검증 결과와 한계](docs/VALIDATION.md), [26개 테스트 케이스 대응표](docs/TEST_PLAN.md)를 구분해 기록합니다. 실행하지 않은 테스트는 통과로 표시하지 않습니다.

## 구조와 담당

```text
lib/core/                 공통 모델, 입력 검증, 실행 모드 선택
lib/data/                 저장소 계약, 데모 구현, Firebase 구현
lib/features/boards/      게시판 목록
lib/features/feed/        피드
lib/features/posts/       글쓰기, 상세, 댓글, 공감, 신고
lib/features/ai/          온디바이스 교정 서비스 계약
test/                    단위·화면·Firestore 규칙 테스트
integration_test/        Android 통합 테스트
scripts/                 로컬 데이터 준비와 검증 도구
```

- `redcc-c`: 앱 기반·익명 인증·게시판·피드·신고
- `GhostRamen918`: 글쓰기·상세·댓글·좋아요
- `Ryoon0504`: 온디바이스 AI·적용/취소·긴 입력·성능

이 역할은 이번 대화에서 정한 시작 배분입니다. 테스트·보고서·AI 활용 기록은 각자가 담당분을 작성하고 코드 통합은 공동으로 진행합니다. [팀원별 시작 안내](docs/TEAM_HANDOFF.md), [데이터 계약](docs/DATA_CONTRACT.md), [협업 방법](CONTRIBUTING.md)을 먼저 읽습니다.

## 프로젝트 문서

- [커뮤니티 운영 기준](GUIDELINES.md)
- [AI 사용 및 코드 수정 기록](prompts_log.md)
- [개발 도구 보안 점검](docs/DEPENDENCIES.md)

공식 참고: [Flutter Android 설정](https://docs.flutter.dev/platform-integration/android/setup), [Flutter 통합 테스트](https://docs.flutter.dev/testing/integration-tests), [Firebase Emulator](https://firebase.google.com/docs/emulator-suite), [Firestore 규칙](https://firebase.google.com/docs/firestore/security/rules-conditions)
