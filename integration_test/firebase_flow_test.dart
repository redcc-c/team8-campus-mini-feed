import 'package:campus_mini_feed/core/bootstrap.dart';
import 'package:campus_mini_feed/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android connects to local anonymous auth and Firestore', (
    tester,
  ) async {
    final services = await bootstrap();
    expect(
      services.isDemo,
      isFalse,
      reason: 'Pass --dart-define=USE_FIREBASE_EMULATORS=true',
    );
    final repo = services.repository;
    addTearDown(repo.dispose);
    final boards = await repo.watchBoards().first.timeout(
      const Duration(seconds: 15),
    );
    expect(
      boards.any((board) => board.id == 'free'),
      isTrue,
      reason: 'Run npm run seed first',
    );
    final post = await repo.createPost(
      boardId: 'free',
      content: 'Firebase Android 통합 테스트',
    );
    final posts = await repo
        .watchPosts('free')
        .firstWhere((posts) => posts.any((value) => value.id == post.id))
        .timeout(const Duration(seconds: 15));
    expect(posts.first.authorId, repo.userId);
    await repo.addComment(postId: post.id, content: '실제 에뮬레이터 댓글');
    expect(
      (await repo
              .watchComments(post.id)
              .firstWhere((comments) => comments.isNotEmpty))
          .single
          .authorId,
      repo.userId,
    );
    await repo.toggleLike(post.id);
    expect(await repo.watchLikes(post.id).first, {repo.userId});
    await repo.toggleLike(post.id);
    expect(await repo.watchLikes(post.id).first, isEmpty);
    await repo.reportPost(postId: post.id, reason: ReportReason.spam);
  });
}
