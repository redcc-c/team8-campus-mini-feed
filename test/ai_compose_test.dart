import 'dart:async';

import 'package:campus_mini_feed/app.dart';
import 'package:campus_mini_feed/core/bootstrap.dart';
import 'package:campus_mini_feed/data/demo_repository.dart';
import 'package:campus_mini_feed/features/ai/correction_service.dart';
import 'package:campus_mini_feed/features/ai/correction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const original = '안되요. 할께요.';
const corrected = '안 돼요. 할게요.';
final contentField = find.byKey(const ValueKey('post-content'));
final titleField = find.byKey(const ValueKey('post-title'));

String content(WidgetTester tester) =>
    tester.widget<TextFormField>(contentField).controller!.text;

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openCompose(
  WidgetTester tester,
  CorrectionService correction, {
  String body = original,
}) async {
  final repository = DemoCommunityRepository();
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    CampusApp(
      services: AppServices(
        repository: repository,
        correction: correction,
        isDemo: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tapKey(tester, 'filter-free');
  await tapKey(tester, 'compose');
  await tester.enterText(titleField, '최신 화면에서 AI 교정');
  await tester.enterText(contentField, body);
  await tester.pumpAndSettle();
}

CorrectionResult suggestions(String text) => CorrectionResult(
  originalText: text,
  suggestions: const [
    CorrectionSuggestion(start: 0, end: 3, replacement: '안 돼요', reason: '맞춤법'),
    CorrectionSuggestion(start: 5, end: 8, replacement: '할게요', reason: '맞춤법'),
  ],
);

class _Correction implements CorrectionService {
  _Correction({this.handler});
  final Future<CorrectionResult> Function(String)? handler;
  bool Function()? cancelled;

  @override
  bool get isAvailable => true;

  @override
  Future<CorrectionResult> check(
    String text, {
    void Function(int, int)? onProgress,
    bool Function()? isCancelled,
  }) {
    cancelled = isCancelled;
    onProgress?.call(1, 2);
    return handler?.call(text) ?? Future.value(suggestions(text));
  }
}

void main() {
  testWidgets(
    'comment correction returns selected text through the existing interface',
    (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  changed = await showCorrectionSheet(
                    context,
                    _Correction(),
                    original,
                  );
                },
                child: const Text('댓글 교정'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('댓글 교정'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'ai-apply');
      expect(changed, '안 돼요. 할께요.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsupported AI explains the limit without blocking publishing', (
    tester,
  ) async {
    await openCompose(tester, const UnavailableCorrectionService());
    expect(
      find.text('이 기기에서는 온디바이스 AI 교정을 사용할 수 없습니다. 글쓰기는 이용할 수 있습니다.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('ai-check')))
          .onPressed,
      isNull,
    );
    await tapKey(tester, 'publish');
    await tester.tap(find.text('최신 화면에서 AI 교정'));
    await tester.pumpAndSettle();
    expect(find.text(original), findsOneWidget);
  });

  testWidgets('selective apply and undo preserve title and photo controls', (
    tester,
  ) async {
    await openCompose(tester, _Correction());
    await tapKey(tester, 'ai-check');
    expect(find.text('교정 제안 2개'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'ai-apply');
    expect(content(tester), '안 돼요. 할께요.');
    expect(
      tester.widget<TextFormField>(titleField).controller!.text,
      '최신 화면에서 AI 교정',
    );
    expect(find.text('사진'), findsOneWidget);
    await tapKey(tester, 'undo-correction');
    expect(content(tester), original);
  });

  testWidgets('all suggestions apply and the corrected post can be published', (
    tester,
  ) async {
    await openCompose(tester, _Correction());
    await tapKey(tester, 'ai-check');
    await tapKey(tester, 'ai-select-all');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ai-apply')))
          .onPressed,
      isNull,
    );
    await tapKey(tester, 'ai-select-all');
    await tapKey(tester, 'ai-apply');
    expect(content(tester), corrected);
    await tapKey(tester, 'publish');
    await tester.tap(find.text('최신 화면에서 AI 교정'));
    await tester.pumpAndSettle();
    expect(find.text(corrected), findsOneWidget);
  });

  testWidgets(
    'keeping the original and editing after apply preserve author control',
    (tester) async {
      await openCompose(tester, _Correction());
      await tapKey(tester, 'ai-check');
      await tapKey(tester, 'ai-keep-original');
      expect(content(tester), original);
      await tapKey(tester, 'ai-check');
      await tapKey(tester, 'ai-apply');
      await tester.enterText(contentField, '직접 작성한 내용');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('undo-correction')), findsNothing);
      expect(content(tester), '직접 작성한 내용');
    },
  );

  testWidgets('cancel restores editing and ignores a late result', (
    tester,
  ) async {
    final gate = Completer<CorrectionResult>();
    final service = _Correction(handler: (_) => gate.future);
    await openCompose(tester, service);
    await tester.ensureVisible(find.byKey(const ValueKey('ai-check')));
    await tester.tap(find.byKey(const ValueKey('ai-check')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: contentField, matching: find.byType(TextField)),
          )
          .readOnly,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('publish')))
          .onPressed,
      isNull,
    );
    final cancel = find.byKey(const ValueKey('ai-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    expect(service.cancelled!(), isTrue);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: contentField, matching: find.byType(TextField)),
          )
          .readOnly,
      isFalse,
    );
    gate.complete(suggestions(original));
    await tester.pumpAndSettle();
    expect(find.text('교정 제안 2개'), findsNothing);
    expect(content(tester), original);
    expect(find.text('검사를 중지했습니다. 원문은 유지됩니다.'), findsOneWidget);
  });

  testWidgets('service errors preserve the draft and permit retry', (
    tester,
  ) async {
    await openCompose(
      tester,
      _Correction(handler: (_) async => throw StateError('unavailable')),
    );
    await tapKey(tester, 'ai-check');
    expect(content(tester), original);
    expect(find.text('AI 교정을 사용할 수 없습니다. 원문은 유지됩니다.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('ai-check')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('oversized correction leaves the original unchanged', (
    tester,
  ) async {
    final text = List.filled(500, '가').join();
    await openCompose(
      tester,
      _Correction(
        handler: (input) async => CorrectionResult(
          originalText: input,
          suggestions: const [
            CorrectionSuggestion(
              start: 0,
              end: 1,
              replacement: '가가',
              reason: '확장',
            ),
          ],
        ),
      ),
      body: text,
    );
    await tapKey(tester, 'ai-check');
    await tapKey(tester, 'ai-apply');
    expect(content(tester), text);
    expect(find.text('적용 결과가 글자 수 제한을 벗어납니다. 원문을 유지합니다.'), findsOneWidget);
  });

  testWidgets('suggestions remain usable on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openCompose(tester, _Correction());
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await tapKey(tester, 'ai-check');
    await tapKey(tester, 'ai-apply');
    expect(content(tester), corrected);
    expect(tester.takeException(), isNull);
  });
}
