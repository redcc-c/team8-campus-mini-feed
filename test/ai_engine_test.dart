import 'dart:async';

import 'package:campus_mini_feed/features/ai/benchmark.dart';
import 'package:campus_mini_feed/features/ai/correction_engine.dart';
import 'package:campus_mini_feed/features/ai/correction_service.dart';
import 'package:campus_mini_feed/features/ai/on_device_correction_service.dart';
import 'package:campus_mini_feed/features/ai/proofreader.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_proofreader.dart';

const mixedInput =
    '안녕하세요 😀 오늘은 자료를 https://example.com/a?b=1 에 올렸어요.\n'
    '이번 학기 팀 프로젝트에서 커뮤니티 앱을 만들고 있는데요, 게시판을 여러개 나누고 '
    '익명으로 글을 쓸수 있게 하려고해요. 서버는 파이어베이스를 쓰고 글쓰기 화면에서는 '
    '맞춤법 검사를 기기 안에서 바로 할수 있도록 할 계획이예요.\n\n'
    '마지막 줄입니다!';

Future<int> charTokens(String text) async => text.characters.length;

String applyEverything(CorrectionResult result) =>
    result.applyAll(result.suggestions);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MlKitProofreader channel', () {
    const channel = MethodChannel('campus_mini_feed/proofreader');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('maps replies and prepares each model it can use', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'status' => 'available',
          'tokenizerStatus' => 'downloadable',
          'proofread' => ['가장 확실한 제안', '다른 제안'],
          'countTokens' => 7,
          'metrics' => {
            'pssKb': 2048,
            'thermalStatus': 1,
            'chargeCounterUah': null,
            'batteryPercent': 90,
            'charging': false,
            'device': 'Google Pixel 9',
            'sdk': 36,
          },
          _ => null,
        };
      });
      const proofreader = MlKitProofreader();
      expect(await proofreader.status(), ProofreaderStatus.available);
      expect(await proofreader.canCountTokens(), isFalse);
      expect(await proofreader.proofread('원문'), '가장 확실한 제안');
      expect(calls.last.arguments, {'text': '원문'});
      expect(await proofreader.countTokens('원문'), 7);
      calls.clear();
      await proofreader.prepare();
      expect(calls.map((call) => call.method), [
        'status',
        'prepare',
        'tokenizerStatus',
        'downloadTokenizer',
      ]);
      final metrics = (await proofreader.metrics())!;
      expect(metrics.pssKb, 2048);
      expect(metrics.chargeCounterUah, isNull);
      expect(metrics.charging, isFalse);
    });

    test('maps platform errors to ProofreadException codes', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: '12', message: 'too large'),
      );
      const proofreader = MlKitProofreader();
      expect(await proofreader.status(), ProofreaderStatus.unavailable);
      expect(await proofreader.metrics(), isNull);
      await expectLater(
        proofreader.proofread('긴 글'),
        throwsA(
          isA<ProofreadException>().having((e) => e.tooLarge, 'tooLarge', true),
        ),
      );
    });

    test('a missing platform implementation means unavailable', () async {
      expect(
        await const MlKitProofreader().status(),
        ProofreaderStatus.unavailable,
      );
    });
  });

  group('splitForProofreading', () {
    test('keeps every character and stays under the token limit', () async {
      final pieces = await splitForProofreading(
        mixedInput,
        charTokens,
        tokenLimit: 41,
      );
      expect(pieces.map((piece) => piece.text).join(), mixedInput);
      for (final piece in pieces.where((piece) => piece.editable)) {
        expect(await charTokens(piece.text), lessThan(41));
        expect(piece.text, isNot(contains('\n')));
        expect(piece.text, isNot(contains('https://')));
      }
    });

    test('uses the token counter instead of a character limit', () async {
      // Two tokens per character: a 30-character line must be split for 41.
      final pieces = await splitForProofreading(
        '가나다라마 바사아자차 카타파하가 나다라마바 사아자차카',
        (text) async => text.characters.length * 2,
        tokenLimit: 41,
      );
      final editable = pieces.where((piece) => piece.editable).toList();
      expect(editable.length, greaterThan(1));
      for (final piece in editable) {
        expect(piece.text.characters.length * 2, lessThan(41));
      }
    });

    test('counts a short line once', () async {
      final counted = <String>[];
      await splitForProofreading('짧은 문장입니다. 두 번째 문장.', (text) async {
        counted.add(text);
        return 5;
      });
      expect(counted, ['짧은 문장입니다. 두 번째 문장.']);
    });

    test('does not count lines without letters or digits', () async {
      final counted = <String>[];
      await splitForProofreading('문장입니다.\n...\n😀', (text) async {
        counted.add(text);
        return 5;
      });
      expect(counted, ['문장입니다.']);
    });

    test('without a tokenizer sends each sentence on its own', () async {
      const input = '첫 문장이에요. 둘째 문장이에요!\n셋째 줄';
      final pieces = await splitForProofreading(input, null);
      expect(pieces.map((piece) => piece.text).join(), input);
      expect(
        pieces.where((piece) => piece.editable).map((piece) => piece.text),
        ['첫 문장이에요.', '둘째 문장이에요!', '셋째 줄'],
      );
    });

    test('hard-splits an unbroken word longer than the limit', () async {
      final word = List.filled(25, '가').join();
      final pieces = await splitForProofreading(
        word,
        charTokens,
        tokenLimit: 11,
      );
      expect(pieces.map((piece) => piece.text.characters.length), [10, 10, 5]);
    });

    test('treats a lone carriage return as a line break', () async {
      const input = '첫 줄입니다\r둘째 줄입니다\r\n셋째 줄';
      final pieces = await splitForProofreading(input, charTokens);
      expect(pieces.map((piece) => piece.text).join(), input);
      expect(
        pieces.where((piece) => piece.editable).map((piece) => piece.text),
        ['첫 줄입니다', '둘째 줄입니다', '셋째 줄'],
      );
    });

    test('does not send punctuation-only or emoji-only pieces', () async {
      final pieces = await splitForProofreading('😀😀\n...', charTokens);
      expect(pieces.every((piece) => !piece.editable), isTrue);
    });
  });

  group('wordSuggestions', () {
    test('turns spacing fixes into a whole-word suggestion', () {
      final suggestions = wordSuggestions(
        '이런것들을 수정하고 싶어요.',
        '이런 것들을 수정하고 싶어요.',
        3,
      );
      expect(suggestions, hasLength(1));
      expect(suggestions.single.start, 3);
      expect(suggestions.single.end, 8);
      expect(suggestions.single.replacement, '이런 것들을');
      expect(suggestions.single.reason, '띄어쓰기');
    });

    test('keeps independent changes separately applicable', () {
      const original = '앱이 안되요. 정말 정말 좋아요.';
      final suggestions = wordSuggestions(original, '앱이 안 돼요. 정말 좋아요.', 0);
      expect(suggestions, hasLength(2));
      expect(suggestions.first.reason, '맞춤법·표현');
      expect(suggestions.last.reason, '삭제 제안');
      final result = CorrectionResult(
        originalText: original,
        suggestions: suggestions,
      );
      expect(result.apply(suggestions.first), '앱이 안 돼요. 정말 정말 좋아요.');
      expect(result.apply(suggestions.last), '앱이 안되요. 정말 좋아요.');
      expect(result.applyAll(suggestions), '앱이 안 돼요. 정말 좋아요.');
    });
  });

  test('applyAll rejects overlapping ranges', () {
    const result = CorrectionResult(originalText: '가나다라', suggestions: []);
    expect(
      () => result.applyAll(const [
        CorrectionSuggestion(start: 0, end: 2, replacement: 'A', reason: ''),
        CorrectionSuggestion(start: 1, end: 3, replacement: 'B', reason: ''),
      ]),
      throwsRangeError,
    );
  });

  group('CorrectionEngine', () {
    test('corrects pieces in order and protects URLs', () async {
      final fake = FakeProofreader(
        fixes: {'여러개': '여러 개', '쓸수': '쓸 수', '할수': '할 수', '계획이예요': '계획이에요'},
      );
      final run = await CorrectionEngine(
        fake,
        tokenLimit: 41,
      ).correct(mixedInput);
      final expected = mixedInput
          .replaceAll('여러개', '여러 개')
          .replaceAll('쓸수', '쓸 수')
          .replaceAll('할수', '할 수')
          .replaceAll('계획이예요', '계획이에요');
      expect(run.result.originalText, mixedInput);
      expect(applyEverything(run.result), expected);
      expect(run.result.failedSegments, 0);
      expect(run.requests, fake.requests.length);
      expect(fake.requests.any((text) => text.contains('https://')), isFalse);
    });

    test('keeps a failed piece as written and corrects the rest', () async {
      final fake = FakeProofreader(
        handler: (text) async {
          if (text.contains('실패')) throw const ProofreadException('9');
          return text.replaceAll('안되요', '안 돼요');
        },
      );
      final run = await CorrectionEngine(fake)
          .correct('첫 줄은 안되요.\n둘째 줄은 실패해요.');
      expect(run.result.failedSegments, 1);
      expect(run.result.allFailed, isFalse);
      expect(applyEverything(run.result), '첫 줄은 안 돼요.\n둘째 줄은 실패해요.');
    });

    test('reports when every piece failed', () async {
      final fake = FakeProofreader(
        handler: (_) async => throw const ProofreadException('9'),
      );
      final run = await CorrectionEngine(fake).correct('하나.\n둘.');
      expect(run.result.allFailed, isTrue);
      expect(run.result.suggestions, isEmpty);
    });

    test('retries a too-large piece by halving', () async {
      final fake = FakeProofreader(
        handler: (text) async {
          if (text.characters.length > 15) {
            throw const ProofreadException('12');
          }
          return text.replaceAll('됬', '됐');
        },
      );
      const input = '오늘 일은 잘 됬어요 내일 일도 잘 됬으면 좋겠어요';
      final run = await CorrectionEngine(fake).correct(input);
      expect(run.result.failedSegments, 0);
      expect(applyEverything(run.result), '오늘 일은 잘 됐어요 내일 일도 잘 됐으면 좋겠어요');
      expect(fake.requests.first, input);
    });

    test('stops halving after two levels', () async {
      final fake = FakeProofreader(
        handler: (_) async => throw const ProofreadException('12'),
      );
      const input = '하나 둘 셋 넷 다섯 여섯 일곱 여덟';
      final run = await CorrectionEngine(fake).correct(input);
      expect(fake.requests, hasLength(1 + 2 + 4));
      expect(run.requests, 7);
      expect(run.result.failedSegments, 4);
    });

    test('times out once and sends nothing more in that run', () async {
      final fake = FakeProofreader(handler: (_) => Completer<String>().future);
      final run = await CorrectionEngine(
        fake,
        timeout: const Duration(milliseconds: 20),
      ).correct('첫 줄이에요.\n둘째 줄이에요.\n셋째 줄이에요.');
      expect(fake.requests, hasLength(1));
      expect(run.result.failedSegments, 3);
      expect(run.result.allFailed, isTrue);
    });

    test(
      'waits for an abandoned request before sending the next one',
      () async {
        final pending = Completer<String>();
        var calls = 0;
        final fake = FakeProofreader(
          handler: (text) => ++calls == 1
              ? pending.future
              : Future.value(text.replaceAll('안되요', '안 돼요')),
        );
        final engine = CorrectionEngine(
          fake,
          timeout: const Duration(milliseconds: 50),
        );
        expect((await engine.correct('먼저 보낸 글')).result.failedSegments, 1);
        final next = engine.correct('앱이 안되요');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(fake.requests, hasLength(1));
        pending.complete('먼저 보낸 글');
        final run = await next;
        expect(fake.requests, hasLength(2));
        expect(applyEverything(run.result), '앱이 안 돼요');
      },
    );

    test('treats REQUEST_TOO_SMALL as nothing to fix', () async {
      final fake = FakeProofreader(
        handler: (_) async => throw const ProofreadException('-100'),
      );
      final run = await CorrectionEngine(fake).correct('네');
      expect(run.result.failedSegments, 0);
      expect(run.result.checkedSegments, 1);
    });

    test('keeps the original on an unexpected error', () async {
      final fake = FakeProofreader(
        handler: (_) async => throw StateError('broken'),
      );
      final run = await CorrectionEngine(fake).correct('문장이에요.');
      expect(run.result.failedSegments, 1);
    });

    test('rejects suggestions that change emoji', () async {
      final fake = FakeProofreader(
        handler: (text) async =>
            text.replaceAll('\u{FE0F}', '').replaceAll('조와요', '좋아요'),
      );
      final run = await CorrectionEngine(fake).correct('조와요 ❤️');
      expect(run.result.failedSegments, 1);
      expect(run.result.suggestions, isEmpty);
    });

    test('stops sending pieces once cancelled', () async {
      final fake = FakeProofreader();
      var cancel = false;
      await CorrectionEngine(fake).correct(
        '첫 줄\n둘째 줄\n셋째 줄',
        isCancelled: () => cancel,
        onProgress: (done, _) => cancel = done > 0,
      );
      expect(fake.requests, ['첫 줄']);
    });

    test('does not halve a too-large piece after cancellation', () async {
      var cancel = false;
      final fake = FakeProofreader(
        handler: (_) async {
          cancel = true;
          throw const ProofreadException('12');
        },
      );
      const input = '하나 둘 셋 넷 다섯 여섯 일곱 여덟';
      await CorrectionEngine(fake).correct(input, isCancelled: () => cancel);
      expect(fake.requests, [input]);
    });

    test('stops token counting once cancelled', () async {
      final fake = FakeProofreader();
      final run = await CorrectionEngine(fake)
          .correct('첫 줄\n둘째 줄', isCancelled: () => true);
      expect(fake.tokenRequests, isEmpty);
      expect(fake.requests, isEmpty);
      expect(run.result.suggestions, isEmpty);
    });

    test('devices without the tokenizer still correct by sentence', () async {
      final fake = FakeProofreader(
        tokenizerAvailable: false,
        fixes: {'안되요': '안 돼요', '됬어요': '됐어요'},
      );
      final run = await CorrectionEngine(fake).correct('앱이 안되요. 잘 됬어요.');
      expect(fake.tokenRequests, isEmpty);
      expect(fake.requests, ['앱이 안되요.', '잘 됬어요.']);
      expect(applyEverything(run.result), '앱이 안 돼요. 잘 됐어요.');
    });
  });

  group('OnDeviceCorrectionService', () {
    test('a stuck status check does not block startup', () async {
      final service = await OnDeviceCorrectionService.create(
        _HangingStatus(),
        const Duration(milliseconds: 20),
      );
      expect(service.isAvailable, isFalse);
    });

    test('is available unless the device cannot run the model', () async {
      final downloadable = await OnDeviceCorrectionService.create(
        FakeProofreader(statusValue: ProofreaderStatus.downloadable),
      );
      expect(downloadable.isAvailable, isTrue);
      final unsupported = await OnDeviceCorrectionService.create(
        FakeProofreader(statusValue: ProofreaderStatus.unavailable),
      );
      expect(unsupported.isAvailable, isFalse);
      await expectLater(unsupported.check('원문'), throwsUnsupportedError);
    });

    test('a preparation failure stops a model that is not ready', () async {
      final fake = FakeProofreader(
        statusValue: ProofreaderStatus.downloadable,
        prepareError: const ProofreadException('501'),
      );
      final service = OnDeviceCorrectionService(fake, isAvailable: true);
      await expectLater(
        service.check('원문'),
        throwsA(isA<ProofreadException>()),
      );
      expect(fake.requests, isEmpty);
    });

    test('a ready model still works when warm-up fails', () async {
      final fake = FakeProofreader(
        fixes: {'안되요': '안 돼요'},
        prepareError: const ProofreadException('9'),
      );
      final result = await OnDeviceCorrectionService(
        fake,
        isAvailable: true,
      ).check('앱이 안되요');
      expect(applyEverything(result), '앱이 안 돼요');
    });

    test('a second check joins a preparation still running', () async {
      final fake = _SlowPrepare();
      final service = OnDeviceCorrectionService(fake, isAvailable: true);
      final first = service.check('첫 글');
      final second = service.check('둘째 글');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fake.prepareCalls, 1);
      fake.gate.complete();
      await Future.wait([first, second]);
      expect(fake.prepareCalls, 1);
    });
  });

  test('LatencyStats uses mean, median and nearest-rank p95', () {
    final even = LatencyStats.of([400, 100, 300, 200])!;
    expect(even.mean, 250);
    expect(even.median, 250);
    expect(even.p95, 400);
    final twenty = LatencyStats.of([for (var i = 1; i <= 20; i++) i])!;
    expect(twenty.median, 11);
    expect(twenty.p95, 19);
    expect(LatencyStats.of(const []), isNull);
  });

  group('BenchmarkRunner', () {
    test('runs fixed inputs and separates the first request', () async {
      final fake = FakeProofreader();
      final progress = <int>[];
      final report = await BenchmarkRunner(
        fake,
        rounds: 2,
      ).run(onProgress: (done, _) => progress.add(done));
      expect(fake.prepareCalls, 1);
      expect(report.samples, hasLength(2 * benchmarkInputs.length));
      expect(progress.last, 2 * benchmarkInputs.length);
      expect(report.warm!.count, 2 * benchmarkInputs.length - 1);
      final markdown = report.toMarkdown();
      expect(markdown, contains('| 첫 교정 소요 시간 (토큰 계산 포함) |'));
      expect(markdown, contains('| 그중 교정 요청 시간 평균 / 중앙값 / 95백분위수 |'));
      expect(markdown, contains('Fake Phone (Android SDK 36)'));
      expect(markdown, isNot(contains('null')));
    });

    test('excludes failed runs from latency statistics', () async {
      final fake = FakeProofreader(
        handler: (text) async {
          if (text.contains('도서관')) throw const ProofreadException('9');
          return text;
        },
      );
      final report = await BenchmarkRunner(fake, rounds: 2).run();
      expect(report.samples.where((s) => s.failures > 0), hasLength(2));
      expect(report.warm!.count, 2 * benchmarkInputs.length - 1 - 2);
      expect(report.toMarkdown(), contains('실패가 있었던 2회는 응답 시간 통계에서 제외했습니다.'));
    });

    test('does not compute battery use while charging', () async {
      final report = await BenchmarkRunner(
        FakeProofreader(charging: true),
        rounds: 1,
      ).run();
      expect(report.toMarkdown(), contains('충전 중이라 소모량을 계산하지 않음'));
    });

    test('stops when cancelled and reports it', () async {
      var runs = 0;
      final report = await BenchmarkRunner(
        FakeProofreader(),
      ).run(onProgress: (done, _) => runs = done, isCancelled: () => runs >= 3);
      expect(report.samples, hasLength(3));
      expect(report.toMarkdown(), contains('중간에 중지됨'));
    });

    test('sustained AI mode counts failed corrections separately', () async {
      final fake = FakeProofreader(
        handler: (_) async => throw const ProofreadException('9'),
      );
      final report = await BenchmarkRunner(fake)
          .sustained(duration: const Duration(milliseconds: 30), useAi: true);
      expect(report.requests, 0);
      expect(report.failedRuns, greaterThan(0));
    });

    test('reports unmeasurable values instead of inventing them', () {
      final report = BenchmarkReport(
        startedAt: DateTime(2026, 11, 9),
        finishedAt: DateTime(2026, 11, 9),
        prepareMs: 0,
        samples: const [],
        start: null,
        end: null,
        peakPssKb: null,
        baseModel: null,
        cancelled: false,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('| 첫 교정 소요 시간 (토큰 계산 포함) | 측정 불가 |'));
      expect(markdown, contains('측정 불가 / 측정 불가 / 측정 불가'));
    });
  });
}

class _HangingStatus extends FakeProofreader {
  @override
  Future<ProofreaderStatus> status() => Completer<ProofreaderStatus>().future;
}

class _SlowPrepare extends FakeProofreader {
  final gate = Completer<void>();

  @override
  Future<void> prepare() async {
    prepareCalls++;
    await gate.future;
  }
}
