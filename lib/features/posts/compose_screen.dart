import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../core/validation.dart';
import '../../widgets/async_content.dart';
import '../ai/correction_service.dart';

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
  CorrectionResult? _result;
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
    setState(() => _checking = true);
    try {
      final result = await widget.services.correction
          .check(original)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (_content.text != original || result.originalText != original) {
        showNotice(context, '글이 변경됐습니다. 다시 검사해 주세요.');
        return;
      }
      setState(() => _result = result);
      if (result.suggestions.isEmpty) showNotice(context, '수정 제안이 없습니다.');
    } catch (_) {
      if (mounted) showNotice(context, 'AI 교정을 사용할 수 없습니다. 원문은 유지됩니다.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _apply(CorrectionSuggestion suggestion) {
    final result = _result;
    if (result == null || _content.text != result.originalText) return;
    try {
      final changed = result.apply(suggestion);
      if (validateContent(changed) != null) {
        showNotice(context, '적용 결과가 글자 수 제한을 벗어납니다. 원문을 유지합니다.');
        return;
      }
      setState(() {
        _undo = _content.text;
        _content.text = changed;
        _result = null;
      });
    } catch (_) {
      showNotice(context, '제안을 적용하지 못했습니다. 원문을 유지합니다.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('새 글 작성')),
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
            minLines: 7,
            maxLines: 12,
            validator: (value) => validateContent(value ?? ''),
            onChanged: (_) => setState(() {
              _result = null;
              _undo = null;
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
                        _result = null;
                      }),
                icon: const Icon(Icons.undo),
              ),
            ],
          ),
          if (!widget.services.correction.isAvailable)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('AI 교정 모델이 아직 연결되지 않았습니다. 글쓰기는 이용할 수 있습니다.'),
            ),
          if (_result case final result?)
            for (final suggestion in result.suggestions)
              Card(
                child: ListTile(
                  title: Text(suggestion.replacement),
                  subtitle: Text(suggestion.reason),
                  trailing: TextButton(
                    onPressed: () => _apply(suggestion),
                    child: const Text('적용'),
                  ),
                ),
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
