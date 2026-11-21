import 'correction_engine.dart';
import 'correction_service.dart';
import 'proofreader.dart';

/// On-device proofreading through ML Kit; the text never leaves the device.
class OnDeviceCorrectionService implements CorrectionService {
  OnDeviceCorrectionService(this.proofreader, {required this.isAvailable})
    : engine = CorrectionEngine(proofreader);

  static Future<OnDeviceCorrectionService> create([
    Proofreader proofreader = const MlKitProofreader(),
    Duration statusTimeout = const Duration(seconds: 5),
  ]) async {
    ProofreaderStatus status;
    try {
      // App startup waits for this check; a stuck AICore must not block it.
      status = await proofreader.status().timeout(statusTimeout);
    } catch (_) {
      status = ProofreaderStatus.unavailable;
    }
    return OnDeviceCorrectionService(
      proofreader,
      isAvailable: status != ProofreaderStatus.unavailable,
    );
  }

  final Proofreader proofreader;
  final CorrectionEngine engine;

  // A cancelled check leaves its download running natively; the next check
  // joins it instead of starting another.
  Future<void>? _preparing;

  @override
  final bool isAvailable;

  @override
  Future<CorrectionResult> check(
    String text, {
    CorrectionProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!isAvailable) {
      throw UnsupportedError('이 기기에서는 온디바이스 AI 교정을 사용할 수 없습니다.');
    }
    // ML Kit serves one request at a time; '9' is GenAiException BUSY.
    if (!await engine.waitForIdle()) throw const ProofreadException('9');
    try {
      // Also loads an already-downloaded model so the first request does not
      // spend its timeout on loading.
      await (_preparing ??= proofreader.prepare().whenComplete(
        () => _preparing = null,
      ));
    } on ProofreadException {
      // A model that is already available still works without the warm-up.
      if (await proofreader.status() != ProofreaderStatus.available) rethrow;
    }
    final run = await engine.correct(
      text,
      isCancelled: isCancelled,
      onProgress: onProgress,
    );
    return run.result;
  }
}
