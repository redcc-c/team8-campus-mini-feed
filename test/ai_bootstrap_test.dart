import 'dart:async';

import 'package:campus_mini_feed/core/bootstrap.dart';
import 'package:campus_mini_feed/data/demo_repository.dart';
import 'package:campus_mini_feed/features/ai/proofreader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('campus_mini_feed/proofreader');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a stalled tokenizer download does not block preparation', () async {
    final stalled = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'status' => 'available',
        'prepare' => null,
        'tokenizerStatus' => 'downloading',
        'downloadTokenizer' => stalled.future,
        _ => throw MissingPluginException(call.method),
      };
    });
    await const MlKitProofreader().prepare().timeout(
      const Duration(seconds: 1),
    );
    expect(aiDiagnostics.value, '모델 준비 완료 (토크나이저: downloading)');
  });

  test('download progress and failures are shown as diagnostics', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'status':
          return 'downloadable';
        case 'downloadProofreader':
          await messenger.handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('downloadEvent', {
                'type': 'progress',
                'bytes': 104857600,
                'total': 209715200,
              }),
            ),
            (_) {},
          );
          expect(aiDiagnostics.value, '모델 내려받는 중 100.0 / 200.0 MB');
          throw PlatformException(code: '606', message: 'network');
        default:
          throw MissingPluginException(call.method);
      }
    });
    await expectLater(
      const MlKitProofreader().prepare(),
      throwsA(isA<ProofreadException>()),
    );
    expect(aiDiagnostics.value, '오류: downloadProofreader → 606 network');
  });

  test(
    'bootstrap connects correction to the native proofreading channel',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'status':
            return 'available';
          case 'tokenizerStatus':
            return 'unavailable';
          case 'prepare':
            return null;
          case 'proofread':
            final text = (call.arguments as Map)['text'] as String;
            return [text.replaceAll('안되요', '안 돼요')];
          default:
            throw MissingPluginException(call.method);
        }
      });
      final services = await bootstrap();
      addTearDown((services.repository as DemoCommunityRepository).dispose);
      expect(services.correction.isAvailable, isTrue);
      final result = await services.correction.check('오늘 앱이 안되요.');
      expect(result.applyAll(result.suggestions), '오늘 앱이 안 돼요.');
      expect(result.originalText, '오늘 앱이 안되요.');
    },
  );

  test('bootstrap keeps the app usable without a native AI plugin', () async {
    final services = await bootstrap();
    addTearDown((services.repository as DemoCommunityRepository).dispose);
    expect(services.correction.isAvailable, isFalse);
    expect(services.isDemo, isTrue);
    expect(services.repository, isA<DemoCommunityRepository>());
  });
}
