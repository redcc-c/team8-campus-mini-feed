# 공통 데이터 계약

현재 클래스는 `lib/core/models.dart`, 저장소 계약은 `lib/data/community_repository.dart`에 있다. 화면은 `CommunityRepository`에 의존하며 Firebase SDK를 직접 호출하지 않는다.

| 데이터 | 경로 | 필드 |
| --- | --- | --- |
| Board | `boards/{boardId}` | `name: string`, `description: string` |
| FeedPost | `posts/{postId}` | `boardId: string`, `authorId: UID`, `content: string`, `createdAt: timestamp` |
| FeedComment | `posts/{postId}/comments/{commentId}` | `authorId: UID`, `content: string`, `createdAt: timestamp` |
| Like | `posts/{postId}/likes/{userId}` | `userId: UID`, `createdAt: timestamp` |
| Report | `posts/{postId}/reports/{reporterId}` | `reporterId: UID`, `reason: spam/abuse/inappropriate/other`, `createdAt: timestamp` |

모델의 `id`, 댓글 모델의 `postId`는 Firestore 문서 경로에서 얻는다. 동일 정보를 다른 문서 필드에 중복 저장하지 않는다. 시간은 Firebase 구현에서 서버 타임스탬프를 사용하고 화면 경계에서 DateTime으로 변환한다.

본문은 최대 500개, 댓글은 최대 200개의 Unicode 코드 포인트로 제한한다. 한 이모지가 여러 코드 포인트로 구성될 수 있으므로 사용자에게 보이는 글리프 수와는 다를 수 있다. Dart는 `.runes.length`, Firestore는 Unicode 정규식 길이 제한을 사용한다. 공백만 있는 본문은 양쪽에서 거절한다. AI 토큰 제한은 별도다.

피드는 게시판 ID로 필터링하고 작성 시각 내림차순으로 최신 50개를 받는다. 댓글은 작성 시각 오름차순으로 최초 100개를 받는다. 더 보기와 실시간 페이지네이션은 후속 개발 범위다.

## 초기 보안 규칙

- 익명 인증을 포함해 인증된 사용자만 게시판·글·댓글·공감을 읽는다.
- 앱 사용자는 샘플 게시판을 직접 만들지 못한다. 초기 게시판은 로컬 시드가 생성한다.
- 게시글·댓글은 본인의 UID와 서버 시각, 정해진 필드·본문 제한을 만족해야 한다.
- 좋아요는 사용자 UID 문서 하나로 중복을 막고 본인만 삭제할 수 있다. 게시글의 임의 카운터를 수정하지 않는다.
- 신고는 본인 UID 문서로 한 번만 생성하며 클라이언트에서 읽기·수정·삭제를 허용하지 않는다.
- 게시글 편집·삭제와 하위 데이터 정리는 아직 제공하지 않는다.

이 규칙은 초기 개발 기준이다. 실제 서비스 전에는 관리자 역할·신고 처리·계정 수명·요청 제한·데이터 삭제 정책을 추가 설계한다. 규칙 테스트를 통과했다고 운영 보안 검토가 끝난 것으로 기록하지 않는다.
