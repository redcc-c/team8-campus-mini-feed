import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../core/validation.dart';
import '../../data/demo_repository.dart';
import '../../widgets/async_content.dart';
import '../../widgets/campus_style.dart';
import '../ai/correction_sheet.dart';

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
  bool _saveFailed = false;
  bool _checking = false;
  bool _pickingPhoto = false;
  String? _photoError;
  final _photos = <Uint8List>[];
  bool _askingToDiscard = false;
  String? _undo;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_saving ||
        _checking ||
        _pickingPhoto ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      final repository = widget.services.repository;
      final request =
          repository is DemoCommunityRepository && _photos.isNotEmpty
          ? repository.createPostWithPhotos(
              boardId: _selectedBoardId!,
              title: _title.text,
              content: _content.text,
              photos: _photos,
            )
          : repository.createPost(
              boardId: _selectedBoardId!,
              title: _title.text,
              content: _content.text,
            );
      final post = await request.timeout(const Duration(seconds: 15));
      if (mounted) Navigator.of(context).pop(post);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhotos() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pickingPhoto = true;
      _photoError = null;
    });
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      final remaining = 5 - _photos.length;
      final selected = await Future.wait(
        files.take(remaining).map((file) => file.readAsBytes()),
      );
      if (mounted) {
        setState(() {
          _photos.addAll(selected);
          if (files.length > remaining) _photoError = '사진은 최대 5장까지 첨부할 수 있어요.';
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _photoError = error.code.contains('access')
              ? '사진 접근이 제한되어 있어요. 사진 없이 글을 등록할 수 있어요.'
              : '사진을 불러오지 못했어요. 다시 선택해 주세요.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _photoError = '사진을 불러오지 못했어요. 다시 선택해 주세요.');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _check() async {
    final error = validateContent(_content.text);
    if (error != null) {
      showNotice(context, error);
      return;
    }
    final original = _content.text;
    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    try {
      final changed = await showCorrectionSheet(
        context,
        widget.services.correction,
        original,
      );
      if (!mounted || changed == null || _content.text != original) return;
      if (validateContent(changed) != null) {
        showNotice(context, '교정 결과가 입력 제한을 벗어났어요. 원문을 유지했어요.');
        return;
      }
      setState(() {
        _undo = original;
        _content.text = changed;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _discardDraft(bool didPop) async {
    if (didPop || _saving || _askingToDiscard) return;
    _askingToDiscard = true;
    final leave = await showCampusSheet<bool>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          const Text(
            '작성 중인 글이 있어요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Text(
            '나가면 작성한 내용이 사라져요.',
            style: TextStyle(fontSize: 15, color: CampusColors.secondaryInk),
          ),
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
    );
    _askingToDiscard = false;
    if (mounted && leave == true) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<FeedPost>(
    canPop:
        !_saving &&
        _title.text.isEmpty &&
        _content.text.isEmpty &&
        _photos.isEmpty,
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
                  FormField<String>(
                    initialValue: _selectedBoardId,
                    validator: (value) =>
                        value == null ? '게시판을 선택해 주세요.' : null,
                    builder: (field) {
                      final board = widget.boards
                          .where((board) => board.id == field.value)
                          .firstOrNull;
                      return InkWell(
                        key: const ValueKey('post-board'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saving
                            ? null
                            : () async {
                                FocusScope.of(context).unfocus();
                                final selected = await _pickBoard();
                                if (!mounted || selected == null) return;
                                field.didChange(selected.id);
                                if (field.hasError) field.validate();
                                setState(() => _selectedBoardId = selected.id);
                              },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            errorText: field.errorText,
                          ),
                          child: Row(
                            spacing: 8,
                            children: [
                              Expanded(
                                child: Text(
                                  board?.name ?? '게시판을 선택해 주세요',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const CampusIcon('chevron-down'),
                            ],
                          ),
                        ),
                      );
                    },
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
                    onChanged: (_) => setState(() => _undo = null),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 144),
                      child: OutlinedButton(
                        key: ValueKey(
                          _undo == null ? 'ai-check' : 'undo-correction',
                        ),
                        onPressed: _saving || _checking
                            ? null
                            : _undo != null
                            ? () => setState(() {
                                _content.text = _undo!;
                                _undo = null;
                              })
                            : widget.services.correction.isAvailable &&
                                  _content.text.trim().isNotEmpty
                            ? _check
                            : null,
                        child: Text(_undo == null ? '교정하기' : '교정 되돌리기'),
                      ),
                    ),
                  ),
                  if (widget.services.repository
                      is DemoCommunityRepository) ...[
                    const SizedBox(height: 8),
                    _photoPicker(),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${anonymousName(widget.services.repository.userId)} 이름으로 게시돼요',
                    style: const TextStyle(
                      fontSize: 13,
                      color: CampusColors.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_saveFailed)
            const ColoredBox(
              color: CampusColors.errorSoft,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  spacing: 12,
                  children: [
                    CampusIcon('write-error', size: 24),
                    Expanded(
                      child: Text(
                        '글을 등록하지 못했어요. 작성한 내용은 그대로 남아 있어요.',
                        style: TextStyle(
                          fontSize: 15,
                          color: CampusColors.error,
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
                  onPressed: _saving || _checking || _pickingPhoto
                      ? null
                      : _publish,
                  child: Text(
                    _saving ? '등록 중…' : (_saveFailed ? '다시 등록하기' : '등록하기'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _photoPicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('사진', '${_photos.length} / 5'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox.square(
            dimension: 72,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: CampusColors.muted,
              ),
              onPressed: _saving || _pickingPhoto || _photos.length == 5
                  ? null
                  : _pickPhotos,
              child: _pickingPhoto
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Tooltip(
                      message: '사진 첨부',
                      child: CampusIcon('camera'),
                    ),
            ),
          ),
          for (final (index, photo) in _photos.indexed)
            SizedBox.square(
              dimension: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(photo, fit: BoxFit.cover),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: '사진 삭제',
                      onPressed: _saving || _pickingPhoto
                          ? null
                          : () => setState(() {
                              _photos.removeAt(index);
                              _photoError = null;
                            }),
                      icon: const CampusIcon('remove-photo'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (_photoError case final message?)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            message,
            style: const TextStyle(color: CampusColors.error),
          ),
        ),
    ],
  );

  Future<Board?> _pickBoard() => showCampusSheet<Board>(
    context,
    (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        const Text(
          '어느 게시판에 올릴까요?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const Text(
          '게시할 곳을 하나 선택해 주세요.',
          style: TextStyle(fontSize: 14, color: CampusColors.secondaryInk),
        ),
        for (final board in widget.boards)
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(board),
            child: Text(board.name),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
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
