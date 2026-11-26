# Firebase 로컬 개발 안내

현재 앱은 체험 모드와 Emulator 모드만 자동으로 선택한다. 실제 Firebase 프로젝트 생성·Google 로그인·결제·원격 배포는 이 초기 준비에 포함하지 않았다.

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

## 실제 Firebase 테스트 프로젝트 연결 시 할 일

담당자와 팀원이 공동으로 프로젝트와 접근 권한을 정한다. Authentication 익명 로그인을 활성화하고 Firestore를 준비한 뒤 FlutterFire CLI로 플랫폼 앱을 등록한다. 생성한 로컬 `firebase_options.dart`와 플랫폼 구성을 사용하도록 `lib/core/bootstrap.dart`에 실제 프로젝트용 분기를 명시적으로 추가한다. 현재 Emulator 분기의 `demoProjectId`를 운영 ID로 단순 치환하지 않는다.

연결 후 실제 테스트 프로젝트에서 두 기기 동기화, 인덱스, 보안 규칙, 오프라인 저장·재시도와 중복 제출을 검증한다. 작성 중 15초 시간 초과가 나도 SDK에 이미 전달된 쓰기는 나중에 완료될 수 있다. 현재 시작 버전은 이를 취소하거나 요청 ID로 중복을 방지하지 않으므로, 재시도 기능을 완성할 때 동일 요청 ID와 서버 확인 절차를 설계한다.

공식 참고: [Flutter 설정](https://firebase.google.com/docs/flutter/setup), [Firestore Emulator](https://firebase.google.com/docs/emulator-suite/connect_firestore), [CLI와 별칭](https://firebase.google.com/docs/cli#source_control_and_project_aliases)
