import 'package:flutter/services.dart';

enum ProofreaderStatus { unavailable, downloadable, downloading, available }

class ProofreadException implements Exception {
  const ProofreadException(this.code, [this.message]);

  /// Values of `GenAiException.ErrorCode`, or `UNKNOWN`/`EMPTY`/`MISSING`.
  final String code;
  final String? message;

  bool get tooLarge => code == '12';

  /// REQUEST_TOO_SMALL: the text is too short to check, not an error.
  bool get tooSmall => code == '-100';

  @override
  String toString() => 'ProofreadException($code, $message)';
}

class DeviceMetrics {
  const DeviceMetrics({
    required this.pssKb,
    this.thermalStatus,
    this.chargeCounterUah,
    this.batteryPercent,
    this.charging,
    this.device,
    this.sdk,
  });

  factory DeviceMetrics.fromMap(Map<Object?, Object?> map) => DeviceMetrics(
    pssKb: map['pssKb']! as int,
    thermalStatus: map['thermalStatus'] as int?,
    chargeCounterUah: map['chargeCounterUah'] as int?,
    batteryPercent: map['batteryPercent'] as int?,
    charging: map['charging'] as bool?,
    device: map['device'] as String?,
    sdk: map['sdk'] as int?,
  );

  final int pssKb;
  final int? thermalStatus;
  final int? chargeCounterUah;
  final int? batteryPercent;
  final bool? charging;
  final String? device;
  final int? sdk;
}

abstract interface class Proofreader {
  /// Availability of proofreading itself.
  Future<ProofreaderStatus> status();

  /// Downloads (if needed) and loads the proofreading model, and the
  /// tokenizer where the device supports it.
  Future<void> prepare();

  Future<String?> baseModel();

  /// Returns the most confident suggestion for [text].
  Future<String> proofread(String text);

  /// Whether [countTokens] works here. The Prompt API that provides the
  /// tokenizer supports fewer devices than Proofreading (e.g. not Galaxy S25).
  Future<bool> canCountTokens();

  /// Counts [text] with the on-device Gemini Nano tokenizer.
  Future<int> countTokens(String text);

  /// Returns `null` where the platform cannot report metrics.
  Future<DeviceMetrics?> metrics();

  /// Keeps the screen on so long measurements stay in the foreground, where
  /// on-device inference is allowed.
  Future<void> keepScreenOn(bool on);
}

/// ML Kit GenAI Proofreading, with the Prompt API used only to count tokens.
class MlKitProofreader implements Proofreader {
  const MlKitProofreader();

  static const _channel = MethodChannel('campus_mini_feed/proofreader');

  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw ProofreadException(error.code, error.message);
    } on MissingPluginException catch (error) {
      throw ProofreadException('MISSING', error.message);
    }
  }

  Future<ProofreaderStatus> _status(String method) async {
    try {
      return switch (await _call<String>(method)) {
        'available' => ProofreaderStatus.available,
        'downloadable' => ProofreaderStatus.downloadable,
        'downloading' => ProofreaderStatus.downloading,
        _ => ProofreaderStatus.unavailable,
      };
    } on ProofreadException {
      return ProofreaderStatus.unavailable;
    }
  }

  @override
  Future<ProofreaderStatus> status() => _status('status');

  @override
  Future<void> prepare() async {
    if (await _status('status') != ProofreaderStatus.available) {
      await _call<void>('downloadProofreader');
    }
    await _call<void>('prepare');
    final tokenizer = await _status('tokenizerStatus');
    if (tokenizer == ProofreaderStatus.downloadable ||
        tokenizer == ProofreaderStatus.downloading) {
      await _call<void>('downloadTokenizer');
    }
  }

  @override
  Future<String?> baseModel() => _call<String>('baseModel');

  @override
  Future<String> proofread(String text) async {
    final suggestions = await _call<List<Object?>>('proofread', {'text': text});
    final best = suggestions?.whereType<String>().firstOrNull;
    if (best == null) throw const ProofreadException('EMPTY');
    return best;
  }

  @override
  Future<bool> canCountTokens() async =>
      await _status('tokenizerStatus') == ProofreaderStatus.available;

  @override
  Future<int> countTokens(String text) async {
    final tokens = await _call<int>('countTokens', {'text': text});
    if (tokens == null) throw const ProofreadException('EMPTY');
    return tokens;
  }

  @override
  Future<DeviceMetrics?> metrics() async {
    try {
      final map = await _call<Map<Object?, Object?>>('metrics');
      return map == null ? null : DeviceMetrics.fromMap(map);
    } on ProofreadException {
      return null;
    }
  }

  @override
  Future<void> keepScreenOn(bool on) => _call<void>('keepScreenOn', {'on': on});
}
