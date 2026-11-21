import 'dart:async';

import 'package:campus_mini_feed/features/ai/benchmark_screen.dart';
import 'package:campus_mini_feed/features/ai/proofreader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_proofreader.dart';

Future<void> openBenchmark(WidgetTester tester, FakeProofreader fake) async {
  await tester.pumpWidget(
    MaterialApp(home: BenchmarkScreen(proofreader: fake)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'measurement produces a copyable report and releases screen wake',
    (tester) async {
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
      await tester.scrollUntilVisible(
        find.text('결과 복사'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('결과 복사'));
      await tester.pumpAndSettle();
      expect(copied, startsWith('## AI 교정 성능 측정 결과'));
      expect(copied, contains('| 3 | 10 |'));
      expect(fake.screenOn, [true, false]);
    },
  );

  testWidgets('measurement cancellation shows a partial report', (
    tester,
  ) async {
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

  testWidgets('backgrounding excludes invalid benchmark results', (
    tester,
  ) async {
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

  testWidgets('unsupported device does not generate measured results', (
    tester,
  ) async {
    await openBenchmark(
      tester,
      FakeProofreader(statusValue: ProofreaderStatus.unavailable),
    );
    await tester.tap(find.text('기본 측정 (입력 10개 × 3회)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('측정하지 않았어요'), findsOneWidget);
  });

  testWidgets('preparation timeout is reported and releases screen wake', (
    tester,
  ) async {
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
}
