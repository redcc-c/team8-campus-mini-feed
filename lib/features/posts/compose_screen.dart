import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../core/validation.dart';
import '../../widgets/async_content.dart';
import '../../widgets/campus_style.dart';
import '../ai/correction_service.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    required this.services,
    required this.boards,
    this.board,
    super.key,
  });
  final AppServices services;
  final List<Board> boards;
  final Board? board;
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  late String? _selectedBoardId = widget.board?.id;
  bool _saving = false;
  bool _checking = false;
  bool _askingToDiscard = false;
  CorrectionResult? _result;
  String? _undo;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_saving || _checking || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final post = await widget.services.repository
          .createPost(
            boardId: _selectedBoardId!,
            title: _title.text,
            content: _content.text,
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) Navigator.of(context).pop(post);
    } catch (_) {
      if (mounted) {
        showNotice(context, '저장하지 못했습니다. 작성한 내용은 유지됩니다. 연결을 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _check() async {
    final error = validateContent(_content.text);
    if (error != null) {
      showNotice(context, error);
      return;
    }
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

  Future<void> _discardDraft(bool didPop) async {
    if (didPop || _saving || _askingToDiscard) return;
    _askingToDiscard = true;
    final leave = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('작성 중인 글이 있어요', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('나가면 작성한 내용이 사라져요.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('나가기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('계속 쓰기'),
            ),
          ],
        ),
      ),
    );
    _askingToDiscard = false;
    if (mounted && leave == true) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<FeedPost>(
    canPop: !_saving && _title.text.isEmpty && _content.text.isEmpty,
    onPopInvokedWithResult: (didPop, _) => _discardDraft(didPop),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        leading: const CampusBackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _fieldLabel('게시판'),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('post-board'),
                    initialValue: _selectedBoardId,
                    isExpanded: true,
                    icon: const CampusIcon('chevron-down'),
                    decoration: const InputDecoration(hintText: '게시판을 선택해 주세요'),
                    items: [
                      for (final board in widget.boards)
                        DropdownMenuItem(
                          value: board.id,
                          child: Text(board.name),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (id) => setState(() => _selectedBoardId = id),
                    validator: (value) =>
                        value == null ? '게시판을 선택해 주세요.' : null,
                  ),
                  const SizedBox(height: 8),
                  _fieldLabel(
                    '제목',
                    '${_title.text.runes.length} / $maxTitleLength',
                  ),
                  TextFormField(
                    key: const ValueKey('post-title'),
                    controller: _title,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: '제목을 입력해 주세요'),
                    validator: (value) => validateContent(
                      value ?? '',
                      maxLength: maxTitleLength,
                      emptyMessage: '제목을 입력해 주세요.',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _fieldLabel(
                    '내용',
                    '${_content.text.runes.length} / $maxPostLength',
                  ),
                  TextFormField(
                    key: const ValueKey('post-content'),
                    controller: _content,
                    enabled: !_saving,
                    minLines: 6,
                    maxLines: 12,
                    decoration: const InputDecoration(hintText: '내용을 입력해 주세요'),
                    validator: (value) => validateContent(value ?? ''),
                    onChanged: (_) => setState(() {
                      _result = null;
                      _undo = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      key: const ValueKey('ai-check'),
                      onPressed:
                          widget.services.correction.isAvailable &&
                              !_checking &&
                              !_saving
                          ? _check
                          : null,
                      child: Text(_checking ? '검사 중…' : '교정하기'),
                    ),
                  ),
                  if (_undo != null)
                    TextButton(
                      key: const ValueKey('undo-correction'),
                      onPressed: _saving || _checking
                          ? null
                          : () => setState(() {
                              _content.text = _undo!;
                              _undo = null;
                              _result = null;
                            }),
                      child: const Text('교정 되돌리기'),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${anonymousName(widget.services.repository.userId)} 이름으로 게시돼요',
                    style: const TextStyle(
                      fontSize: 13,
                      color: CampusColors.secondaryInk,
                    ),
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
                ],
              ),
            ),
          ),
          ColoredBox(
            color: CampusColors.surface,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('publish'),
                  onPressed: _saving || _checking ? null : _publish,
                  child: Text(_saving ? '등록 중…' : '등록하기'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _fieldLabel(String label, [String? count]) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        if (count != null)
          Text(
            count,
            style: const TextStyle(
              fontSize: 12,
              color: CampusColors.tertiaryInk,
            ),
          ),
      ],
    ),
  );
}
