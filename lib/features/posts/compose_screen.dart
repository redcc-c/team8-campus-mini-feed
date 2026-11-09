import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../core/validation.dart';
import '../../widgets/async_content.dart';
import '../ai/benchmark_screen.dart';
import '../ai/correction_sheet.dart';
import '../ai/correction_service.dart';
import '../ai/on_device_correction_service.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({required this.services, required this.board, super.key});
  final AppServices services;
  final Board board;
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _form = GlobalKey<FormState>();
  final _content = TextEditingController();
  bool _saving = false;
  bool _checking = false;
  // Incremented to cancel a running check; stale checks discard their result.
  int _checkRun = 0;
  int _checked = 0;
  int _toCheck = 0;
  String? _aiNotice;
  String? _undo;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.services.repository
          .createPost(boardId: widget.board.id, content: _content.text)
          .timeout(const Duration(seconds: 15));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        showNotice(context, '저장하지 못했습니다. 작성한 내용은 유지됩니다. 연결을 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _check() async {
    if (!_form.currentState!.validate()) return;
    final original = _content.text;
    final run = ++_checkRun;
    bool cancelled() => run != _checkRun || !mounted;
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _checked = 0;
      _toCheck = 0;
      _aiNotice = null;
    });
    try {
      final result = await widget.services.correction.check(
        original,
        isCancelled: cancelled,
        onProgress: (done, total) {
          if (!cancelled()) {
            setState(() {
              _checked = done;
              _toCheck = total;
            });
          }
        },
      );
      if (!mounted || cancelled()) return;
      setState(() => _checking = false);
      if (_content.text != original || result.originalText != original) {
        setState(() => _aiNotice = '글이 변경됐습니다. 다시 검사해 주세요.');
        return;
      }
      if (result.allFailed) {
        setState(
          () => _aiNotice = '지금은 AI 교정을 하지 못했습니다. 원문은 유지됩니다. 잠시 후 다시 시도해 주세요.',
        );
        return;
      }
      final selected = await showModalBottomSheet<List<CorrectionSuggestion>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => CorrectionSheet(result: result),
      );
      if (!mounted || selected == null) return;
      _apply(result, selected);
    } catch (_) {
      if (!cancelled()) {
        setState(() => _aiNotice = 'AI 교정을 사용할 수 없습니다. 원문은 유지됩니다.');
      }
    } finally {
      if (!cancelled()) setState(() => _checking = false);
    }
  }

  void _cancelCheck() => setState(() {
    _checkRun++;
    _checking = false;
    _aiNotice = '검사를 중지했습니다. 원문은 유지됩니다.';
  });

  void _apply(CorrectionResult result, List<CorrectionSuggestion> selected) {
    if (_content.text != result.originalText) {
      setState(() => _aiNotice = '글이 변경됐습니다. 다시 검사해 주세요.');
      return;
    }
    try {
      final changed = result.applyAll(selected);
      if (validateContent(changed) != null) {
        setState(() => _aiNotice = '적용 결과가 글자 수 제한을 벗어납니다. 원문을 유지합니다.');
        return;
      }
      setState(() {
        _undo = result.originalText;
        _content.text = changed;
        _aiNotice = 'AI 교정을 적용했습니다. 되돌리기 버튼으로 원문을 복원할 수 있습니다.';
      });
    } on RangeError {
      setState(() => _aiNotice = '제안을 적용하지 못했습니다. 원문을 유지합니다.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('새 글 작성'),
      actions: [
        if (widget.services.correction case final OnDeviceCorrectionService ai
            when !kReleaseMode)
          IconButton(
            tooltip: 'AI 성능 측정',
            icon: const Icon(Icons.speed_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BenchmarkScreen(proofreader: ai.proofreader),
              ),
            ),
          ),
      ],
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '${widget.board.name} 게시판',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('post-content'),
            controller: _content,
            enabled: !_saving,
            readOnly: _checking,
            minLines: 7,
            maxLines: 12,
            validator: (value) => validateContent(value ?? ''),
            onChanged: (_) => setState(() {
              _undo = null;
              _aiNotice = null;
            }),
            decoration: InputDecoration(
              hintText: '캠퍼스에서 나누고 싶은 이야기를 적어 주세요.',
              counterText: '${_content.text.runes.length} / $maxPostLength',
            ),
          ),
          const SizedBox(height: 12),
          Text('${anonymousName(widget.services.repository.userId)}으로 게시됩니다.'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('ai-check'),
                  onPressed:
                      widget.services.correction.isAvailable &&
                          !_checking &&
                          !_saving
                      ? _check
                      : null,
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: Text(_checking ? '검사 중…' : '글쓰기 교정'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                key: const ValueKey('undo-correction'),
                tooltip: '교정 되돌리기',
                onPressed: _undo == null || _saving || _checking
                    ? null
                    : () => setState(() {
                        _content.text = _undo!;
                        _undo = null;
                        _aiNotice = '교정 전 원문으로 되돌렸습니다.';
                      }),
                icon: const Icon(Icons.undo),
              ),
            ],
          ),
          if (_checking) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _toCheck == 0 ? null : _checked / _toCheck,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _toCheck == 0
                        ? 'AI 모델을 준비하고 있습니다. 처음에는 모델을 내려받느라 몇 분 걸릴 수 있습니다.'
                        : '검사 중 $_checked/$_toCheck',
                  ),
                ),
                TextButton(
                  key: const ValueKey('ai-cancel'),
                  onPressed: _cancelCheck,
                  child: const Text('중지'),
                ),
              ],
            ),
          ],
          if (_aiNotice case final notice?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(notice, key: const ValueKey('ai-notice')),
            ),
          if (widget.services.correction.isAvailable)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('교정은 기기 안에서만 처리되며 작성 내용을 서버로 보내지 않습니다.'),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('이 기기에서는 온디바이스 AI 교정을 사용할 수 없습니다. 글쓰기는 이용할 수 있습니다.'),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('publish'),
            onPressed: _saving || _checking ? null : _publish,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_saving ? '저장 중…' : '게시하기'),
            ),
          ),
        ],
      ),
    ),
  );
}
