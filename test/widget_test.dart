import 'package:campus_mini_feed/app.dart';
import 'package:campus_mini_feed/core/bootstrap.dart';
import 'package:campus_mini_feed/data/demo_repository.dart';
import 'package:campus_mini_feed/features/ai/correction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('latest feed -> filter -> compose -> new post -> detail', (
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
    expect(find.byKey(const ValueKey('feed-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('post-welcome')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-free')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('post-library')), findsOneWidget);
    expect(find.byKey(const ValueKey('post-welcome')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('publish')));
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    expect(find.text('내용을 입력해 주세요.'), findsOneWidget);
    expect(find.text('제목을 입력해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('ai-check')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('post-title')),
      '새로운 캠퍼스 이야기',
    );
    await tester.enterText(
      find.byKey(const ValueKey('post-content')),
      '함께 만드는 캠퍼스',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('publish')));
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    final posted = find.byKey(const ValueKey('post-local-1'));
    expect(posted, findsOneWidget);
    expect(
      find.descendant(of: posted, matching: find.text('방금 전')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(posted).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('post-library'))).dy,
      ),
    );
    await tester.tap(find.text('새로운 캠퍼스 이야기'));
    await tester.pumpAndSettle();
    expect(find.text('게시글 상세'), findsOneWidget);
    expect(find.text('함께 만드는 캠퍼스'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('like')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('like')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
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
    await tester.tap(find.byKey(const ValueKey('filter-free')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-title')),
      '연결이 불안정해요',
    );
    await tester.enterText(
      find.byKey(const ValueKey('post-content')),
      '실패해도 유지할 원문',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('publish')));
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    expect(find.text('실패해도 유지할 원문'), findsOneWidget);
    expect(find.text('연결이 불안정해요'), findsOneWidget);
    expect(find.textContaining('작성한 내용은 그대로 남아 있어요'), findsOneWidget);
    expect(find.text('다시 등록하기'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('publish')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('MP1 forms fit a 320-wide layout at 200% text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
    await tester.tap(find.text('수업용 노트북, 어떤 모델 쓰세요?'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comment-content')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final send = find.byKey(const ValueKey('send-comment'));
    expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(500));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post-title')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final publish = find.byKey(const ValueKey('publish'));
    expect(tester.getBottomRight(publish).dy, lessThanOrEqualTo(500));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a post stays bookmarked across tabs and opens the report sheet',
    (tester) async {
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
      final firstPost = find.byKey(const ValueKey('post-welcome'));
      await tester.tap(
        find.descendant(of: firstPost, matching: find.byTooltip('북마크 저장')),
      );
      await tester.tap(find.text('북마크'));
      await tester.pumpAndSettle();
      expect(find.text('저장한 글 1개'), findsOneWidget);
      await tester.tap(find.text('수업용 노트북, 어떤 모델 쓰세요?'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('신고하기'));
      await tester.pumpAndSettle();
      expect(find.text('이 글을 신고할까요?'), findsOneWidget);
      final send = find.widgetWithText(FilledButton, '신고하기');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.ensureVisible(find.text('기타'));
      await tester.tap(find.text('기타'));
      await tester.pumpAndSettle();
      final details = find.byType(TextField).last;
      await tester.ensureVisible(details);
      await tester.enterText(details, '테스트 신고 내용');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('신고가 접수됐어요'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('북마크 해제'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('저장한 글이 없어요'), findsOneWidget);
    },
  );
}

class _FailingRepository extends DemoCommunityRepository {
  @override
  Future<Never> createPost({
    required String boardId,
    required String content,
    String? title,
  }) async => throw StateError('Simulated offline write failure');
}
