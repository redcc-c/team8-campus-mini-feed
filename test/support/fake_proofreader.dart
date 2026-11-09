import 'dart:async';

import 'package:campus_mini_feed/features/ai/proofreader.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Test double for the on-device model. Its tokenizer counts one token per
/// character; it does not imitate Gemini Nano's real token counts.
class FakeProofreader implements Proofreader {
  FakeProofreader({
    this.statusValue = ProofreaderStatus.available,
    this.fixes = const {},
    this.handler,
    this.prepareError,
    this.charging = false,
    this.tokenizerAvailable = true,
  });

  ProofreaderStatus statusValue;
  final Map<String, String> fixes;
  final Future<String> Function(String text)? handler;
  final Object? prepareError;
  final bool charging;
  final bool tokenizerAvailable;
  final requests = <String>[];
  final tokenRequests = <String>[];
  final screenOn = <bool>[];
  int prepareCalls = 0;
  int _pss = 100000;

  @override
  Future<ProofreaderStatus> status() async => statusValue;

  @override
  Future<void> prepare() async {
    prepareCalls++;
    if (prepareError != null) throw prepareError!;
    statusValue = ProofreaderStatus.available;
  }

  @override
  Future<String?> baseModel() async => 'fake-nano';

  @override
  Future<String> proofread(String text) {
    requests.add(text);
    if (handler != null) return handler!(text);
    var result = text;
    fixes.forEach((from, to) => result = result.replaceAll(from, to));
    return Future.value(result);
  }

  @override
  Future<bool> canCountTokens() async => tokenizerAvailable;

  @override
  Future<int> countTokens(String text) async {
    tokenRequests.add(text);
    return text.characters.length;
  }

  @override
  Future<DeviceMetrics?> metrics() async => DeviceMetrics(
    pssKb: _pss += 1024,
    thermalStatus: 0,
    chargeCounterUah: 4000000,
    batteryPercent: 80,
    charging: charging,
    device: 'Fake Phone',
    sdk: 36,
  );

  @override
  Future<void> keepScreenOn(bool on) async => screenOn.add(on);
}
