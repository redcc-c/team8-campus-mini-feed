import 'package:campus_mini_feed/core/models.dart';
import 'package:campus_mini_feed/core/validation.dart';
import 'package:campus_mini_feed/data/demo_repository.dart';
import 'package:campus_mini_feed/features/ai/correction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo starts with ten posts and supports the unfiltered feed', () async {
    final repository = DemoCommunityRepository();
    addTearDown(repository.dispose);
    final samples = await repository.watchPosts().first;
    expect(samples, hasLength(10));
    expect(samples.every((post) => post.title?.isNotEmpty ?? false), isTrue);
    final posted = await repository.createPost(
      boardId: 'dev',
      title: '새 글',
      content: '본문',
    );
    expect((await repository.watchPosts().first).first.id, posted.id);
    expect((await repository.watchPosts('dev').first).first.title, '새 글');
  });

  test(
    'post validation rejects blank/oversized input and keeps Unicode boundary',
    () {
      expect(validateContent(' \n\t　'), isNotNull);
      expect(validateContent('가' * 500), isNull);
      expect(validateContent('가' * 501), isNotNull);
      expect(validateContent('🙂' * 500), isNull);
      expect(validateContent('🙂' * 501), isNotNull);
      expect(requireContent('  글  '), '글');
      expect(
        validateContent('가' * 201, maxLength: maxCommentLength),
        isNotNull,
      );
    },
  );
  test(
    'relative time handles current, minutes, hours, days and clock skew',
    () {
      final now = DateTime(2026, 11, 2, 12);
      expect(relativeTime(now, now: now), '방금 전');
      expect(
        relativeTime(now.add(const Duration(minutes: 1)), now: now),
        '방금 전',
      );
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5분 전',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 2)), now: now),
        '2시간 전',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 1)), now: now),
        '1일 전',
      );
    },
  );
  test(
    'demo repository validates board, sorts posts and isolates board feeds',
    () async {
      final repo = DemoCommunityRepository(seed: false);
      addTearDown(repo.dispose);
      await expectLater(
        repo.createPost(boardId: 'unknown', content: '글'),
        throwsArgumentError,
      );
      await expectLater(
        repo.createPost(boardId: 'free', content: ' '),
        throwsArgumentError,
      );
      final first = await repo.createPost(boardId: 'free', content: '첫 글');
      final second = await repo.createPost(boardId: 'free', content: '두 번째 글');
      await repo.createPost(boardId: 'study', content: '공부 글');
      expect((await repo.watchPosts('free').first).map((post) => post.id), [
        second.id,
        first.id,
      ]);
      expect((await repo.watchPosts('study').first).single.content, '공부 글');
    },
  );
  test(
    'comments, likes and reports preserve ownership and reject missing posts',
    () async {
      final repo = DemoCommunityRepository(seed: false);
      addTearDown(repo.dispose);
      final post = await repo.createPost(boardId: 'free', content: '테스트');
      await repo.addComment(postId: post.id, content: '댓글');
      expect(
        (await repo.watchComments(post.id).first).single.authorId,
        repo.userId,
      );
      await repo.toggleLike(post.id);
      expect(await repo.watchLikes(post.id).first, {repo.userId});
      await repo.toggleLike(post.id);
      expect(await repo.watchLikes(post.id).first, isEmpty);
      await repo.reportPost(postId: post.id, reason: ReportReason.spam);
      await expectLater(
        repo.reportPost(postId: post.id, reason: ReportReason.other),
        throwsStateError,
      );
      await expectLater(repo.toggleLike('missing'), throwsStateError);
    },
  );
  test(
    'AI contract applies only the selected range without mutating original',
    () {
      const suggestion = CorrectionSuggestion(
        start: 0,
        end: 2,
        replacement: '안녕하세요',
        reason: '인사',
      );
      const result = CorrectionResult(
        originalText: '안녕 캠퍼스',
        suggestions: [suggestion],
      );
      expect(result.apply(suggestion), '안녕하세요 캠퍼스');
      expect(result.originalText, '안녕 캠퍼스');
      expect(
        () => result.apply(
          const CorrectionSuggestion(
            start: 0,
            end: 999,
            replacement: '',
            reason: '오류',
          ),
        ),
        throwsRangeError,
      );
    },
  );
  test('unconnected AI never returns pretend corrections', () async {
    const service = UnavailableCorrectionService();
    expect(service.isAvailable, isFalse);
    await expectLater(service.check('원문'), throwsUnsupportedError);
  });
}
