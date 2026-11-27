# Firebase 실행 안내

기본 실행은 메모리 기반 체험 모드다. 실제 팀 프로젝트에 글을 저장하려면 클라우드 모드로 실행한다.

## 팀 프로젝트에 연결하기 (Android)

1. Firebase 콘솔에 Android 앱 `com.team8.campus_mini_feed`를 등록하고 Authentication의 로그인 방법에서 **익명**을 활성화한다. Cloud Firestore 기본 데이터베이스를 생성한다.
2. 처음 한 번 또는 규칙·인덱스 변경 시 저장소 루트에서 `npm.cmd ci`, `npx.cmd firebase login`, `npx.cmd firebase deploy --only firestore --project YOUR_PROJECT_ID`를 실행한다. 현재 규칙은 게시글의 제목도 허용한다.
3. 콘솔의 Firestore 데이터 탭에서 `boards/free` 문서를 만들고 문자열 필드 `name`과 `description`을 입력한다. 예시는 각각 `자유`, `캠퍼스 이야기`다. 게시판이 하나 이상 있어야 홈에 글쓰기 버튼이 표시된다.
4. 저장소 루트에 `.env`가 없으면 `Copy-Item .env.example .env`로 만든다. `USE_FIREBASE_CLOUD=true`를 지정하고 Android 앱의 등록 정보를 채운다. 로컬 Emulator 플래그는 끈다.

| .env 키 | google-services.json의 해당 Android 앱 값 |
| --- | --- |
| FIREBASE_PROJECT_ID | project_info.project_id |
| FIREBASE_MESSAGING_SENDER_ID | project_info.project_number |
| FIREBASE_APP_ID | client_info.mobilesdk_app_id |
| FIREBASE_API_KEY | api_key의 current_key |

Android 기기를 연결하거나 가상 기기를 켜고 다음 명령을 실행한다.

```powershell
flutter pub get
flutter devices
# emulator-5554 자리에 위 목록의 Android 기기 ID를 입력한다.
flutter run -d emulator-5554 --dart-define-from-file=.env
```

최신 홈에서 게시판을 선택하고 제목·본문을 등록한 뒤 Firestore의 `posts` 문서를 확인한다. 같은 설정으로 실행한 두 번째 기기의 최신 홈과 해당 게시판에서도 글을 볼 수 있다. 당겨서 새로고침하면 서버에 다시 조회한다.

## 설치 조건

Node.js 24 LTS와 Java 21을 준비하고 저장소 루트에서 `npm ci`를 실행한다. Firebase CLI는 `package-lock.json`에 고정한 개발 의존성을 사용한다. Java는 Android Studio의 JDK를 사용할 수 있다. Windows 준비 PC에서는 `JAVA_HOME=C:\Program Files\Android\Android Studio\jbr`이다.

```powershell
node --version
java -version
npm.cmd ci
npx.cmd firebase --version
```

## 로컬 실행

```powershell
# 터미널 A
npx.cmd firebase emulators:start --only auth,firestore --project demo-team8-campus
# 터미널 B: 앱을 실행하기 전에 게시판 준비
npm.cmd run seed
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

Authentication은 9099, Firestore는 8080이다. UI가 시작되면 http://127.0.0.1:4000 에서 로컬 데이터를 확인한다. Android 가상 기기는 호스트 PC를 `10.0.2.2`로 연결한다. 앱은 `Firebase.initializeApp(name: '[DEFAULT]', demoProjectId: 'demo-team8-campus')`로 초기화하고 두 Emulator를 명시적으로 연결한 뒤 익명 로그인한다. 기본 앱이 필요한 Firestore 플러그인과의 호환성을 위해 이름을 명시한다.

`.firebaserc` 없이도 모든 명령에 `--project demo-team8-campus`를 전달하므로 작동한다. 팀 별칭 파일을 쓰고 싶다면 `.firebaserc.example`을 `.firebaserc`로 복사한다. 실제 프로젝트 별칭을 공유할지는 팀이 합의한다. `.firebaserc`나 `firebase_options.dart`가 관리자 비밀 키인 것은 아니다.

## 데이터와 테스트

`npm run seed`는 루프백 Emulator만 허용하고 `demo-team8-campus`에만 샘플을 쓴다. 기존 사용자 게시글을 삭제하지 않는다. 운영 자격 증명이나 서비스 계정 파일은 사용하지 않는다.

```powershell
# 별도 세션에서 규칙 검증: 이 명령은 테스트 데이터를 매 테스트마다 초기화한다.
npm.cmd run test:emulators
```

수동 앱 테스트 데이터를 보관하려면 Emulator를 다음처럼 시작한다.

```powershell
npx.cmd firebase emulators:start --only auth,firestore --project demo-team8-campus --export-on-exit=emulator-data
# 내보낸 폴더가 생성된 다음 실행부터:
npx.cmd firebase emulators:start --only auth,firestore --project demo-team8-campus --import=emulator-data --export-on-exit=emulator-data
```

루트의 `emulator-data/`는 Git에서 제외된다. 공유할 의도적인 가상 테스트 데이터는 `test/fixtures/` 아래에 둔다. 민감 데이터를 공유 시드로 만들지 않는다.

## 연결 문제 확인

- 게시판이 없으면 `npm run seed` 실행 여부를 확인한다.
- Windows 방화벽이나 다른 프로그램이 포트를 사용 중이면 해당 상태를 확인한다. 이 준비 작업은 방화벽 설정을 변경하지 않는다.
- Android Emulator 주소는 `127.0.0.1`이 아니라 `10.0.2.2`이다. 앱은 Android 대상에서 이를 자동 선택한다.
- 실기기에서는 `adb reverse tcp:8080 tcp:8080`, `adb reverse tcp:9099 tcp:9099` 후 `--dart-define=EMULATOR_HOST=127.0.0.1`을 추가할 수 있다. 실제 기기에서의 검증은 별도로 기록한다.
- 로컬 HTTP는 Android debug manifest에서만 허용했다. release 앱의 네트워크 보안 설정을 약화시키지 않았다.
- Firestore 인덱스 정의는 저장소에 있지만 Emulator는 실제 서비스의 복합 인덱스 동작을 완전히 대체하지 않는다.

공식 참고: [Flutter 설정](https://firebase.google.com/docs/flutter/setup), [Firestore Emulator](https://firebase.google.com/docs/emulator-suite/connect_firestore), [CLI와 별칭](https://firebase.google.com/docs/cli#source_control_and_project_aliases)
