# 개발 도구 의존성 점검

앱 패키지는 `pubspec.lock`, Node 테스트 도구는 `package-lock.json`으로 고정한다. Node 패키지는 Firebase CLI·로컬 시드·보안 규칙 테스트에 사용하며 Android APK에 포함되지 않는다.

2026-11-02 초기 설치에서 `npm audit`의 high 항목을 확인했다. Firebase JavaScript SDK의 간접 의존성인 `@grpc/grpc-js`에 1.14.7 override를 적용하고 허용 범위 내의 `npm audit fix`를 실행했다. 이후 규칙 테스트 12개를 재실행해 통과했다. high/critical 경고는 남지 않았다.

현재 로컬 개발 도구 체인에는 16개의 moderate 경고가 남는다. Firebase CLI의 glob·minimatch·uuid·OpenTelemetry 등 간접 의존성에서 발생한다. `npm audit fix --force`가 제안한 Firebase CLI 구버전으로의 강제 변경은 하지 않았다. upstream 업데이트를 검토하고 lockfile을 갱신할 때 다시 감사한다.

Emulator는 루프백에만 바인딩하고 가상 데이터만 사용한다. 경고가 없어졌다고 임의로 기록하지 않는다. 실제 서비스를 배포하기 전에는 앱과 개발 도구의 의존성을 다시 점검한다.

Android 빌드는 현재 성공하지만 Firebase Core/Auth 플러그인에 대해 향후 Flutter의 Built-in Kotlin 전환 관련 경고가 출력된다. Flutter를 업그레이드할 때 플러그인의 호환 버전과 마이그레이션 안내를 함께 확인한다. 현재 초기 프로젝트는 고정한 Flutter 3.47.5에서 검증했다.

## 온디바이스 AI (2026-11-09 추가)

| 의존성 | 용도 | 비고 |
| --- | --- | --- |
| `com.google.mlkit:genai-proofreading:1.0.0-beta1` | 기기 안 Gemini Nano 맞춤법 교정 | 베타. 입력 256토큰 미만, API 26 이상, AICore 지원 기기 한정 |
| `com.google.mlkit:genai-prompt:1.0.0-beta4` | `countTokens`로 Gemini Nano 토크나이저 토큰 수 계산 | 베타. 교정 문장 생성에는 사용하지 않음. Proofreading보다 지원 기기가 적어(예: Galaxy S25 미지원) 없으면 문장 단위 분할로 동작 |

두 의존성 때문에 Android `minSdk`를 26으로 올렸다. Flutter 패키지(`pubspec.yaml`, `pubspec.lock`)는 변경하지 않았다. 베타 API이므로 버전을 올릴 때 오류 코드와 지원 기기 목록을 다시 확인한다.
