import 'package:campus_mini_feed/app.dart';
import 'package:campus_mini_feed/core/bootstrap.dart';
import 'package:campus_mini_feed/data/demo_repository.dart';
import 'package:campus_mini_feed/features/ai/correction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android demo can publish a post and open its details', (
    tester,
  ) async {
    final repo = DemoCommunityRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      CampusApp(
        services: AppServices(
          repository: repo,
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
      'Android 통합 테스트 게시글',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.ensureVisible(find.byKey(const ValueKey('publish')));
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Android 통합 테스트 게시글'));
    await tester.pumpAndSettle();
    expect(find.text('게시글 상세'), findsOneWidget);
    expect(find.text('Android 통합 테스트 게시글'), findsOneWidget);
  });
}
