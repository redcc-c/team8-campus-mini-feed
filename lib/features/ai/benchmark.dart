import 'dart:async';
import 'dart:math';

import 'correction_engine.dart';
import 'proofreader.dart';

/// Fixed inputs: short, long, typo, spacing, emoji, English, URL, line breaks.
const benchmarkInputs = [
  '이런것들을 수정하고 싶어요.',
  '이 기능을 사용해도 괜찮을 꺼야.',
  '앱이 실행이 안되요.',
  '오늘 날씨가 정말 정말 좋아요.',
  '내일 수업 끝나고 도서관에서 만나요 😀 늦지 않게 와 주세요!',
  'Flutter 앱에서 setState를 쓰면 화면이 다시 그려져요.',
  '자료는 https://example.com/notes 에 올려 두었어요. 확인 부탁드려요.',
  '시험기간에는 하루에 세시간씩 복습하고있어요. 다들 화이팅 하세요.',
  '이번 학기 팀 프로젝트에서 커뮤니티 앱을 만들고 있는데요, 게시판을 여러개 나누고 '
      '익명으로 글을 쓸수 있게 하려고해요. 서버는 파이어베이스를 쓰고 글쓰기 화면에서는 '
      '맞춤법 검사를 기기 안에서 바로 할수 있도록 할 계획이예요. 혹시 비슷한 프로젝트를 '
      '해본 분이 있다면 어떤 점이 어려웟는지 알려주시면 정말 감사하겠습니다.',
  '첫째 줄은 인사말이에요.\n둘째 줄에는 오타가 있슴니다.\n\n셋째 줄은 비워 둔 줄 다음이에요.',
];

class LatencyStats {
  const LatencyStats._(this.count, this.mean, this.median, this.p95);

  static LatencyStats? of(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final n = sorted.length;
    final mean = sorted.reduce((a, b) => a + b) / n;
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : ((sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2).round();
    // Nearest-rank percentile.
    final p95 = sorted[max(0, (0.95 * n).ceil() - 1)];
    return LatencyStats._(n, mean, median, p95);
  }

  final int count;
  final double mean;
  final int median;
  final int p95;
}

class BenchmarkSample {
  const BenchmarkSample({
    required this.round,
    required this.input,
    required this.latencyMs,
    required this.inferenceMs,
    required this.requests,
    required this.failures,
  });

  final int round;
  final int input;

  /// Whole correction, including token counting.
  final int latencyMs;

  /// Proofreading requests only.
  final int inferenceMs;
  final int requests;
  final int failures;
}

String thermalLabel(int? status) {
  const labels = ['없음', '약함', '보통', '심함', '위험', '비상', '종료'];
  if (status == null || status < 0 || status >= labels.length) return '측정 불가';
  return '${labels[status]}($status)';
}

String _mb(int? kb) =>
    kb == null ? '측정 불가' : '${(kb / 1024).toStringAsFixed(1)} MB';

String _battery(DeviceMetrics? start, DeviceMetrics? end) {
  if (start?.charging == true || end?.charging == true) {
    return '충전 중이라 소모량을 계산하지 않음 (충전기를 분리하고 다시 측정하세요)';
  }
  final percent = start?.batteryPercent != null && end?.batteryPercent != null
      ? '${start!.batteryPercent}% → ${end!.batteryPercent}%'
      : '측정 불가';
  final startCharge = start?.chargeCounterUah;
  final endCharge = end?.chargeCounterUah;
  final charge = startCharge != null && endCharge != null
      ? '${((startCharge - endCharge) / 1000).toStringAsFixed(1)} mAh 소모'
      : '전하량 측정 불가';
  return '$percent, $charge';
}

String _device(DeviceMetrics? metrics) => metrics?.device == null
    ? '알 수 없음'
    : '${metrics!.device} (Android SDK ${metrics.sdk})';

class BenchmarkReport {
  const BenchmarkReport({
    required this.startedAt,
    required this.finishedAt,
    required this.prepareMs,
    required this.samples,
    required this.start,
    required this.end,
    required this.peakPssKb,
    required this.baseModel,
    required this.cancelled,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final int prepareMs;
  final List<BenchmarkSample> samples;
  final DeviceMetrics? start;
  final DeviceMetrics? end;
  final int? peakPssKb;
  final String? baseModel;
  final bool cancelled;

  BenchmarkSample? get first => samples.firstOrNull;

  /// Failed samples are excluded: a timeout or instant error is not a latency.
  LatencyStats? get warm => LatencyStats.of([
    for (final s in samples.skip(1))
      if (s.failures == 0) s.latencyMs,
  ]);

  LatencyStats? get warmInference => LatencyStats.of([
    for (final s in samples.skip(1))
      if (s.failures == 0) s.inferenceMs,
  ]);

  /// Warm runs of the first input, comparable with the first request.
  LatencyStats? get warmFirstInput => LatencyStats.of([
    for (final s in samples.skip(1))
      if (s.failures == 0 && s.input == first!.input) s.latencyMs,
  ]);

  String toMarkdown() {
    final warm = this.warm;
    final inference = warmInference;
    final first = this.first;
    final sameInput = first == null ? null : warmFirstInput;
    final failedRuns = samples.where((s) => s.failures > 0).length;
    final growth = start != null && end != null
        ? '${((end!.pssKb - start!.pssKb) / 1024).toStringAsFixed(1)} MB'
        : '측정 불가';
    final buffer = StringBuffer()
      ..writeln('## AI 교정 성능 측정 결과')
      ..writeln()
      ..writeln('- 기기: ${_device(start)}')
      ..writeln('- 기본 모델: ${baseModel ?? '확인 불가'}')
      ..writeln(
        '- 측정 시각: ${startedAt.toIso8601String()} ~ ${finishedAt.toIso8601String()}',
      )
      ..writeln(
        '- 입력: 고정 입력 ${benchmarkInputs.length}개, 완료 ${samples.length}회'
        '${cancelled ? ' (중간에 중지됨)' : ''}',
      )
      ..writeln()
      ..writeln('| 항목 | 값 |')
      ..writeln('|---|---|')
      ..writeln('| 모델 준비 시간 | $prepareMs ms |')
      ..writeln(
        '| 첫 교정 소요 시간 (토큰 계산 포함) | ${switch (first) {
          null => '측정 불가',
          final s when s.failures > 0 => '측정 불가 (요청 실패)',
          final s => '${s.latencyMs} ms (교정 요청 ${s.inferenceMs} ms)',
        }} |',
      )
      ..writeln(
        warm == null
            ? '| 준비 후 교정 (토큰 계산 포함) | 측정 불가 |'
            : '| 준비 후 교정 ${warm.count}회 평균 / 중앙값 / 95백분위수 (토큰 계산 포함) | '
                  '${warm.mean.toStringAsFixed(0)} / ${warm.median} / ${warm.p95} ms |',
      )
      ..writeln(
        inference == null
            ? '| 그중 교정 요청 시간 | 측정 불가 |'
            : '| 그중 교정 요청 시간 평균 / 중앙값 / 95백분위수 | '
                  '${inference.mean.toStringAsFixed(0)} / ${inference.median} / ${inference.p95} ms |',
      )
      ..writeln(
        '| 첫 요청과 같은 입력의 준비 후 평균 | ${sameInput == null ? '측정 불가' : '${sameInput.mean.toStringAsFixed(0)} ms (${sameInput.count}회)'} |',
      )
      ..writeln(
        '| 앱 PSS 검사 전 / 최대 / 종료 후 | '
        '${_mb(start?.pssKb)} / ${_mb(peakPssKb)} / ${_mb(end?.pssKb)} |',
      )
      ..writeln('| 앱 PSS 증가량 | $growth |')
      ..writeln(
        '| 열 상태 시작 → 종료 | '
        '${thermalLabel(start?.thermalStatus)} → ${thermalLabel(end?.thermalStatus)} |',
      )
      ..writeln('| 배터리 | ${_battery(start, end)} |')
      ..writeln(
        '| 실제 보낸 요청 수 / 원문 유지 요청 | '
        '${samples.fold(0, (sum, s) => sum + s.requests)} / '
        '${samples.fold(0, (sum, s) => sum + s.failures)} |',
      )
      ..writeln()
      ..writeln('참고: Gemini Nano는 AICore 프로세스에서 실행되므로 앱 PSS는 모델 전체 메모리가 아닙니다.');
    buffer.writeln('최대 PSS는 1초 간격으로 잰 값 중 가장 큰 값이라 짧은 순간의 최대치는 놓칠 수 있습니다.');
    if (failedRuns > 0) {
      buffer.writeln('실패가 있었던 $failedRuns회는 응답 시간 통계에서 제외했습니다.');
    }
    buffer
      ..writeln()
      ..writeln('| 회차 | 입력 | 소요 시간(ms) | 교정 요청 시간(ms) | 요청 수 | 원문 유지 |')
      ..writeln('|---|---|---|---|---|---|');
    for (final sample in samples) {
      buffer.writeln(
        '| ${sample.round + 1} | ${sample.input + 1} | '
        '${sample.latencyMs} | ${sample.inferenceMs} | '
        '${sample.requests} | ${sample.failures} |',
      );
    }
    return buffer.toString();
  }
}

class SustainedReport {
  const SustainedReport({
    required this.useAi,
    required this.elapsed,
    required this.requests,
    required this.failedRuns,
    required this.start,
    required this.end,
    required this.cancelled,
  });

  final bool useAi;
  final Duration elapsed;
  final int requests;

  /// Corrections with at least one failed request; not counted in [requests].
  final int failedRuns;
  final DeviceMetrics? start;
  final DeviceMetrics? end;
  final bool cancelled;

  String toMarkdown() => [
    '## ${useAi ? 'AI 교정 연속 사용' : 'AI 미사용 대기(비교용)'} 측정',
    '',
    '- 기기: ${_device(start)}',
    '- 측정 시간: ${elapsed.inSeconds}초${cancelled ? ' (중간에 중지됨)' : ''}',
    if (useAi) '- 완료한 교정: $requests회 (실패 $failedRuns회)',
    '- 열 상태: ${thermalLabel(start?.thermalStatus)} → ${thermalLabel(end?.thermalStatus)}',
    '- 배터리: ${_battery(start, end)}',
  ].join('\n');
}

class BenchmarkRunner {
  BenchmarkRunner(
    this.proofreader, {
    this.rounds = 3,
    this.sampleEvery = const Duration(seconds: 1),
  }) : engine = CorrectionEngine(proofreader);

  final Proofreader proofreader;
  final CorrectionEngine engine;
  final int rounds;
  final Duration sampleEvery;

  int get totalRuns => rounds * benchmarkInputs.length;

  Future<String?> _baseModel() async {
    try {
      return await proofreader.baseModel();
    } on ProofreadException {
      return null;
    }
  }

  Future<BenchmarkReport> run({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final startedAt = DateTime.now();
    final start = await proofreader.metrics();
    final baseModel = await _baseModel();
    // ML Kit serves one request at a time; '9' is GenAiException BUSY.
    if (!await engine.waitForIdle()) throw const ProofreadException('9');
    final prepare = Stopwatch()..start();
    await proofreader.prepare();
    prepare.stop();

    var peak = start?.pssKb;
    var sampling = false;
    final sampler = Timer.periodic(sampleEvery, (_) async {
      if (sampling) return;
      sampling = true;
      try {
        final metrics = await proofreader.metrics();
        if (metrics != null) peak = max(peak ?? 0, metrics.pssKb);
      } finally {
        sampling = false;
      }
    });
    final samples = <BenchmarkSample>[];
    var cancelled = false;
    try {
      outer:
      for (var round = 0; round < rounds; round++) {
        for (final (index, input) in benchmarkInputs.indexed) {
          if (isCancelled?.call() ?? false) {
            cancelled = true;
            break outer;
          }
          final watch = Stopwatch()..start();
          final run = await engine.correct(input);
          watch.stop();
          samples.add(
            BenchmarkSample(
              round: round,
              input: index,
              latencyMs: watch.elapsedMilliseconds,
              inferenceMs: run.inferenceMs,
              requests: run.requests,
              failures: run.result.failedSegments,
            ),
          );
          onProgress?.call(samples.length, totalRuns);
        }
      }
    } finally {
      sampler.cancel();
    }
    final end = await proofreader.metrics();
    if (end != null) peak = max(peak ?? 0, end.pssKb);
    return BenchmarkReport(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      prepareMs: prepare.elapsedMilliseconds,
      samples: List.unmodifiable(samples),
      start: start,
      end: end,
      peakPssKb: peak,
      baseModel: baseModel,
      cancelled: cancelled,
    );
  }

  Future<SustainedReport> sustained({
    required Duration duration,
    required bool useAi,
    bool Function()? isCancelled,
    void Function(Duration elapsed)? onTick,
  }) async {
    if (!await engine.waitForIdle()) throw const ProofreadException('9');
    if (useAi) await proofreader.prepare();
    final start = await proofreader.metrics();
    final watch = Stopwatch()..start();
    var requests = 0;
    var failedRuns = 0;
    var cancelled = false;
    while (watch.elapsed < duration) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      if (useAi) {
        final run = await engine.correct(
          benchmarkInputs[(requests + failedRuns) % benchmarkInputs.length],
        );
        if (run.result.failedSegments > 0) {
          failedRuns++;
        } else {
          requests++;
        }
      } else {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      onTick?.call(watch.elapsed);
    }
    watch.stop();
    final end = await proofreader.metrics();
    return SustainedReport(
      useAi: useAi,
      elapsed: watch.elapsed,
      requests: requests,
      failedRuns: failedRuns,
      start: start,
      end: end,
      cancelled: cancelled,
    );
  }
}
