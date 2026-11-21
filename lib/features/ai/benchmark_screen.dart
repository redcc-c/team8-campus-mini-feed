import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'benchmark.dart';
import 'proofreader.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({required this.proofreader, super.key});
  final Proofreader proofreader;

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen>
    with WidgetsBindingObserver {
  bool _running = false;
  // Stop requested; the runner finishes its current request and returns a
  // partial report.
  bool _stopping = false;
  // The app left the foreground, where inference is not allowed.
  bool _interrupted = false;
  String _progress = '';
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_running &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused)) {
      setState(() {
        _interrupted = true;
        _stopping = true;
      });
    }
  }

  bool _cancelled() => _stopping || !mounted;

  void _setProgress(String message) {
    if (!_cancelled()) setState(() => _progress = message);
  }

  Future<void> _start(
    Future<String> Function(
      BenchmarkRunner runner,
      bool Function() cancelled,
      void Function(String) progress,
    )
    task,
  ) async {
    final proofreader = widget.proofreader;
    setState(() {
      _running = true;
      _stopping = false;
      _interrupted = false;
      _error = null;
      _result = null;
      _progress = '기기 지원 여부를 확인하고 있어요.';
    });
    var screenKept = false;
    try {
      if (await proofreader.status() == ProofreaderStatus.unavailable) {
        if (mounted) {
          setState(
            () => _error =
                '이 기기에서는 ML Kit 교정을 사용할 수 없어 측정하지 않았어요. '
                '지원 기기에서 다시 실행해 주세요.',
          );
        }
        return;
      }
      await proofreader.keepScreenOn(true);
      screenKept = true;
      _setProgress('AI 모델을 준비하고 있어요.');
      final report = await task(
        BenchmarkRunner(proofreader),
        _cancelled,
        _setProgress,
      );
      if (!mounted) return;
      setState(() {
        if (_interrupted) {
          _error = '측정 중 앱이 화면에서 벗어나 결과를 기록하지 않았어요. 화면을 켠 채로 다시 측정해 주세요.';
        } else {
          _result = report;
        }
      });
    } catch (error) {
      // Includes token-counting timeouts, which are not ProofreadExceptions.
      if (mounted) {
        setState(
          () => _error =
              '측정 중 오류가 발생해 결과를 기록하지 않았어요. '
              '(${error is ProofreadException ? '코드 ${error.code}' : error.runtimeType})',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _stopping = false;
        });
      }
      if (screenKept) await proofreader.keepScreenOn(false);
    }
  }

  void _stop() => setState(() => _stopping = true);

  Future<String> _basic(
    BenchmarkRunner runner,
    bool Function() cancelled,
    void Function(String) progress,
  ) async {
    final report = await runner.run(
      isCancelled: cancelled,
      onProgress: (done, total) => progress('$done/$total회 완료'),
    );
    return report.toMarkdown();
  }

  Future<String> Function(
    BenchmarkRunner,
    bool Function(),
    void Function(String),
  )
  _sustained(bool useAi) => (runner, cancelled, progress) async {
    final report = await runner.sustained(
      duration: const Duration(minutes: 5),
      useAi: useAi,
      isCancelled: cancelled,
      onTick: (elapsed) => progress('${elapsed.inSeconds}초 / 300초'),
    );
    return report.toMarkdown();
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 성능 측정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '같은 기기에서 화면 밝기, 통신 상태, 실행 중인 다른 앱을 고정하고 측정하세요.\n'
                  '기본 측정은 고정 입력 10개를 3회씩 교정합니다.\n'
                  '5분 측정은 교정 사용과 대기를 각각 3번씩 반복해 비교하세요.\n'
                  '측정하지 못한 값은 “측정 불가”로 표시하며 임의 값으로 채우지 않습니다.\n'
                  '앱 PSS에는 AICore 프로세스의 모델 메모리가 포함되지 않습니다.',
                  style: text.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _running ? null : () => _start(_basic),
              child: const Text('기본 측정 (입력 10개 × 3회)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _running ? null : () => _start(_sustained(true)),
              child: const Text('5분 연속 교정'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _running ? null : () => _start(_sustained(false)),
              child: const Text('5분 대기 (비교용)'),
            ),
            if (_running) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(_progress, style: text.bodyMedium)),
                  TextButton(
                    onPressed: _stopping ? null : _stop,
                    child: Text(_stopping ? '중지하는 중' : '중지'),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(_result!, style: text.bodySmall),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _result!));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('측정 결과를 복사했어요.')),
                    );
                },
                icon: const Icon(Icons.copy),
                label: const Text('결과 복사'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
