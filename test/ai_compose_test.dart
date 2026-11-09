import 'dart:async';

import 'package:campus_mini_feed/app.dart';
import 'package:campus_mini_feed/core/bootstrap.dart';
import 'package:campus_mini_feed/data/demo_repository.dart';
import 'package:campus_mini_feed/features/ai/on_device_correction_service.dart';
import 'package:campus_mini_feed/features/ai/proofreader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_proofreader.dart';

const firstLine = '이런것들을 수정하고 싶어요.';
const secondLine = '오늘 날씨가 정말 정말 좋아요.';
const body = '$firstLine\n$secondLine';

final contentField = find.byKey(const ValueKey('post-content'));
final aiNotice = find.byKey(const ValueKey('ai-notice'));

String contentText(WidgetTester tester) =>
    tester.widget<TextFormField>(contentField).controller!.text;

String? noticeText(WidgetTester tester) =>
    aiNotice.evaluate().isEmpty ? null : tester.widget<Text>(aiNotice).data;

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    // Lazily built below the fold on small screens.
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openCompose(
  WidgetTester tester,
  FakeProofreader proofreader, {
  bool available = true,
  String content = body,
}) async {
  final repository = DemoCommunityRepository();
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    CampusApp(
      services: AppServices(
        repository: repository,
        correction: OnDeviceCorrectionService(
          proofreader,
          isAvailable: available,
        ),
        isDemo: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final board = find.byKey(const ValueKey('board-free'));
  await tester.scrollUntilVisible(
    board,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(board);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('compose')));
  await tester.pumpAndSettle();
  await tester.enterText(contentField, content);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('applies one selected suggestion and undoes it', (tester) async {
    final fake = FakeProofreader(fixes: {'이런것들을': '이런 것들을', '정말 정말': '정말'});
    await openCompose(tester, fake);
    await tapKey(tester, 'ai-check');
    expect(find.text('교정 제안 2개'), findsOneWidget);
    expect(fake.requests, [firstLine, secondLine]);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'ai-apply');
    expect(contentText(tester), '이런 것들을 수정하고 싶어요.\n$secondLine');
    await tapKey(tester, 'undo-correction');
    expect(contentText(tester), body);
    expect(noticeText(tester), '교정 전 원문으로 되돌렸습니다.');
  });

  testWidgets('keeping the original leaves the draft untouched', (
    tester,
  ) async {
    await openCompose(tester, FakeProofreader(fixes: {'이런것들을': '이런 것들을'}));
    await tapKey(tester, 'ai-check');
    await tapKey(tester, 'ai-keep-original');
    expect(contentText(tester), body);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-correction')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('editing after applying disables undo', (tester) async {
    await openCompose(tester, FakeProofreader(fixes: {'이런것들을': '이런 것들을'}));
    await tapKey(tester, 'ai-check');
    await tapKey(tester, 'ai-apply');
    await tester.enterText(contentField, '직접 다시 썼어요.');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-correction')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('partial failures are disclosed and kept as written', (
    tester,
  ) async {
    final fake = FakeProofreader(
      handler: (text) async {
        if (text == secondLine) throw const ProofreadException('9');
        return text.replaceAll('이런것들을', '이런 것들을');
      },
    );
    await openCompose(tester, fake);
    await tapKey(tester, 'ai-check');
    expect(find.text('교정하지 못한 부분은 원문으로 유지했습니다.'), findsOneWidget);
    await tapKey(tester, 'ai-apply');
    expect(contentText(tester), '이런 것들을 수정하고 싶어요.\n$secondLine');
  });

  testWidgets('a run where everything failed shows an error, not a sheet', (
    tester,
  ) async {
    final fake = FakeProofreader(
      handler: (_) async => throw const ProofreadException('9'),
    );
    await openCompose(tester, fake);
    await tapKey(tester, 'ai-check');
    expect(
      noticeText(tester),
      '지금은 AI 교정을 하지 못했습니다. 원문은 유지됩니다. 잠시 후 다시 시도해 주세요.',
    );
    expect(find.textContaining('교정 제안'), findsNothing);
    expect(contentText(tester), body);
  });

  testWidgets('reports when nothing needs fixing', (tester) async {
    await openCompose(tester, FakeProofreader());
    await tapKey(tester, 'ai-check');
    expect(find.text('고칠 부분을 찾지 못했습니다.'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(contentText(tester), body);
  });

  testWidgets('unsupported devices keep writing available', (tester) async {
    await openCompose(tester, FakeProofreader(), available: false);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('ai-check')))
          .onPressed,
      isNull,
    );
    expect(
      find.text('이 기기에서는 온디바이스 AI 교정을 사용할 수 없습니다. 글쓰기는 이용할 수 있습니다.'),
      findsOneWidget,
    );
  });

  testWidgets('model preparation failure keeps the draft', (tester) async {
    final fake = FakeProofreader(
      statusValue: ProofreaderStatus.downloadable,
      prepareError: const ProofreadException('501'),
    );
    await openCompose(tester, fake);
    await tapKey(tester, 'ai-check');
    expect(noticeText(tester), 'AI 교정을 사용할 수 없습니다. 원문은 유지됩니다.');
    expect(contentText(tester), body);
  });

  testWidgets('a suggestion over 500 code points is not applied', (
    tester,
  ) async {
    final longBody = '${List.filled(62, '앱이 안되요. ').join()}끝입니다';
    expect(longBody.runes.length, 500);
    await openCompose(
      tester,
      FakeProofreader(fixes: {'안되요': '안 돼요'}),
      content: longBody,
    );
    await tapKey(tester, 'ai-check');
    await tapKey(tester, 'ai-apply');
    expect(noticeText(tester), '적용 결과가 글자 수 제한을 벗어납니다. 원문을 유지합니다.');
    expect(contentText(tester), longBody);
  });

  testWidgets('stopping a check keeps the draft', (tester) async {
    final fake = FakeProofreader(
      handler: (text) =>
          Future.delayed(const Duration(milliseconds: 200), () => text),
    );
    await openCompose(tester, fake);
    await tester.ensureVisible(find.byKey(const ValueKey('ai-check')));
    await tester.tap(find.byKey(const ValueKey('ai-check')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('ai-cancel')));
    await tester.pumpAndSettle();
    expect(noticeText(tester), '검사를 중지했습니다. 원문은 유지됩니다.');
    expect(find.textContaining('교정 제안'), findsNothing);
    expect(contentText(tester), body);
  });

  testWidgets('suggestion sheet fits a small screen at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openCompose(
      tester,
      FakeProofreader(fixes: {'이런것들을': '이런 것들을', '정말 정말': '정말'}),
    );
    // Scaled after navigating: only the compose screen's AI UI is under test.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await tapKey(tester, 'ai-check');
    expect(find.text('교정 제안 2개'), findsOneWidget);
    await tapKey(tester, 'ai-apply');
    expect(contentText(tester), '이런 것들을 수정하고 싶어요.\n오늘 날씨가 정말 좋아요.');
    expect(tester.takeException(), isNull);
  });

  group('benchmark screen', () {
    Future<void> openBenchmark(
      WidgetTester tester,
      FakeProofreader fake,
    ) async {
      await openCompose(tester, fake);
      await tester.tap(find.byTooltip('AI 성능 측정'));
      await tester.pumpAndSettle();
    }

    testWidgets('produces a copyable report', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final fake = FakeProofreader();
      await openBenchmark(tester, fake);
      await tester.tap(find.text('기본 측정 (입력 10개 × 3회)'));
      await tester.pumpAndSettle();
      final copy = find.text('결과 복사');
      await tester.scrollUntilVisible(
        copy,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, startsWith('## AI 교정 성능 측정 결과'));
      expect(copied, contains('| 3 | 10 |'));
      expect(fake.screenOn, [true, false]);
    });

    testWidgets('stopping shows the partial report', (tester) async {
      final fake = FakeProofreader(
        handler: (text) =>
            Future.delayed(const Duration(milliseconds: 100), () => text),
      );
      await openBenchmark(tester, fake);
      await tester.tap(find.text('기본 측정 (입력 10개 × 3회)'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('중지'));
      await tester.pumpAndSettle();
      expect(find.textContaining('(중간에 중지됨)'), findsOneWidget);
      expect(fake.screenOn, [true, false]);
    });

    testWidgets('leaving the app discards the result', (tester) async {
      final fake = FakeProofreader(
        handler: (text) =>
            Future.delayed(const Duration(milliseconds: 100), () => text),
      );
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await openBenchmark(tester, fake);
      await tester.tap(find.text('5분 연속 교정'));
      await tester.pump(const Duration(milliseconds: 350));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      expect(find.textContaining('앱이 화면에서 벗어나 결과를 기록하지 않았어요'), findsOneWidget);
      expect(fake.screenOn, [true, false]);
    });

    testWidgets('refuses to measure on unsupported devices', (tester) async {
      await openBenchmark(
        tester,
        FakeProofreader(statusValue: ProofreaderStatus.unavailable),
      );
      await tester.tap(find.text('기본 측정 (입력 10개 × 3회)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('측정하지 않았어요'), findsOneWidget);
    });

    testWidgets('reports a timeout instead of ending silently', (tester) async {
      final fake = FakeProofreader(prepareError: TimeoutException('slow'));
      await openBenchmark(tester, fake);
      await tester.tap(find.text('기본 측정 (입력 10개 × 3회)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('측정 중 오류가 발생해 결과를 기록하지 않았어요. (TimeoutException)'),
        findsOneWidget,
      );
      expect(fake.screenOn, [true, false]);
    });
  });
}
