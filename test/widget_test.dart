import 'package:campus_mini_feed/app.dart';
import 'package:campus_mini_feed/core/bootstrap.dart';
import 'package:campus_mini_feed/data/demo_repository.dart';
import 'package:campus_mini_feed/features/ai/correction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('board -> compose -> validation -> published post -> detail', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      CampusApp(
        services: AppServices(
          repository: repository,
          correction: const UnavailableCorrectionService(),
          isDemo: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('체험 모드'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('board-free')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('publish')));
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    expect(find.text('내용을 입력해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('ai-check')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('post-content')),
      '함께 만드는 캠퍼스',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('publish')));
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    expect(find.text('함께 만드는 캠퍼스'), findsOneWidget);
    await tester.tap(find.text('함께 만드는 캠퍼스'));
    await tester.pumpAndSettle();
    expect(find.text('게시글 상세'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('like')));
    await tester.pumpAndSettle();
    expect(find.text('공감 1'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('comment-content')));
    await tester.enterText(
      find.byKey(const ValueKey('comment-content')),
      '첫 댓글입니다',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('send-comment')));
    await tester.tap(find.byKey(const ValueKey('send-comment')));
    await tester.pumpAndSettle();
    expect(find.text('첫 댓글입니다'), findsOneWidget);
  });

  testWidgets('a failed save keeps the author text and enables retry', (
    tester,
  ) async {
    final repository = _FailingRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      CampusApp(
        services: AppServices(
          repository: repository,
          correction: const UnavailableCorrectionService(),
          isDemo: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('board-free')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-content')),
      '실패해도 유지할 원문',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('publish')));
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    expect(find.text('실패해도 유지할 원문'), findsOneWidget);
    expect(find.textContaining('작성한 내용은 유지됩니다'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('publish')))
          .onPressed,
      isNotNull,
    );
  });
}

class _FailingRepository extends DemoCommunityRepository {
  @override
  Future<Never> createPost({
    required String boardId,
    required String content,
  }) async => throw StateError('Simulated offline write failure');
}
