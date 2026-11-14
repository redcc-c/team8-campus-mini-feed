import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../core/validation.dart';
import '../../data/community_repository.dart';
import '../../widgets/async_content.dart';
import '../../widgets/campus_style.dart';
import '../ai/correction_sheet.dart';
import '../feed/feed_bookmarks.dart';
import 'post_photo.dart';
import 'post_report.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    required this.services,
    required this.board,
    required this.post,
    required this.bookmarks,
    this.showPhoto = false,
    super.key,
  });
  final AppServices services;
  final Board board;
  final FeedPost post;
  final FeedBookmarks bookmarks;
  final bool showPhoto;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _comment = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final _comments = widget.services.repository.watchComments(
    widget.post.id,
  );
  late final _likes = widget.services.repository.watchLikes(widget.post.id);
  late final _availability = switch (widget.services.repository) {
    final PostAvailability repository => repository.watchPostAvailability(
      widget.post.id,
    ),
    _ => null,
  };
  bool _sending = false;
  bool _liking = false;
  bool _reporting = false;
  bool _reported = false;
  bool _commentFailed = false;
  String? _originalComment;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _commentFailed = false;
    });
    try {
      await widget.services.repository
          .addComment(postId: widget.post.id, content: _comment.text)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        _comment.clear();
        _originalComment = null;
      }
    } catch (_) {
      if (mounted) setState(() => _commentFailed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _correctComment() async {
    final original = _comment.text;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final changed = await showCorrectionSheet(
      context,
      widget.services.correction,
      original,
    );
    if (!mounted || changed == null || _comment.text != original) return;
    if (validateContent(changed, maxLength: maxCommentLength) != null) {
      showNotice(context, '교정 결과가 댓글 입력 제한을 벗어났어요. 원문을 유지했어요.');
      return;
    }
    setState(() {
      _originalComment = original;
      _comment.text = changed;
    });
  }

  void _undoCommentCorrection() => setState(() {
    _comment.text = _originalComment!;
    _originalComment = null;
  });

  Future<void> _toggleLike() async {
    setState(() => _liking = true);
    try {
      await widget.services.repository
          .toggleLike(widget.post.id)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted) showNotice(context, '공감을 반영하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _report() async {
    setState(() => _reporting = true);
    final reported = await openPostReport(
      context,
      widget.services.repository,
      widget.post.id,
    );
    if (!mounted) return;
    setState(() {
      _reporting = false;
      _reported = reported;
    });
  }

  void _openPhoto(int initialIndex) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PhotoViewer(
        post: widget.post,
        initialIndex: initialIndex,
        count: _photoCount,
      ),
    ),
  );

  int get _photoCount =>
      postPhotoCount(widget.post, showSample: widget.showPhoto);

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: _availability,
    builder: (context, snapshot) {
      if (snapshot.data == false) return _unavailablePost();
      return _detail();
    },
  );

  Widget _unavailablePost() => Scaffold(
    appBar: AppBar(
      title: const Text('게시글 상세'),
      leading: const CampusBackButton(),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            const Text(
              '이 글을 볼 수 없어요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Text(
              '삭제되었거나 볼 수 없는 글이에요.',
              style: TextStyle(color: CampusColors.secondaryInk),
            ),
            SizedBox(
              width: 240,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('최신 홈으로'),
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: const ColoredBox(
      color: CampusColors.surface,
      child: SafeArea(
        minimum: EdgeInsets.all(16),
        child: Row(
          spacing: 8,
          children: [
            Expanded(
              child: TextField(
                enabled: false,
                decoration: InputDecoration(hintText: '댓글을 작성할 수 없어요'),
              ),
            ),
            FilledButton(onPressed: null, child: Text('등록')),
          ],
        ),
      ),
    ),
  );

  Widget _detail() => Scaffold(
    appBar: AppBar(
      title: const Text('게시글 상세'),
      leading: const CampusBackButton(),
      actions: [
        IconButton(
          key: const ValueKey('report'),
          tooltip: '게시글 메뉴',
          icon: const CampusIcon('more', size: 24),
          onPressed: _reporting || _reported ? null : _report,
        ),
        if (MediaQuery.textScalerOf(context).scale(22) < 34)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ListenableBuilder(
              listenable: widget.bookmarks,
              builder: (_, _) => CampusBookmarkButton(
                selected: widget.bookmarks.hasPost(widget.post.id),
                onPressed: () => widget.bookmarks.togglePost(widget.post.id),
              ),
            ),
          ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.board.name,
                style: const TextStyle(
                  color: CampusColors.onPrimarySoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _metadata(widget.post.authorId, widget.post.createdAt),
              const SizedBox(height: 8),
              if (widget.post.title case final title?) ...[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SelectableText(
                widget.post.content,
                style: const TextStyle(fontSize: 16, height: 26 / 16),
              ),
              if (_photoCount > 0) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _openPhoto(0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Semantics(
                      label: '게시글 사진 확대',
                      child: postPhoto(
                        widget.post,
                        0,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              StreamBuilder<List<FeedComment>>(
                stream: _comments,
                builder: (context, snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _likeButton(),
                        const SizedBox(width: 8),
                        const CampusIcon('comment'),
                        const SizedBox(width: 8),
                        Text(
                          '${snapshot.data?.length ?? 0}',
                          style: _metaStyle,
                        ),
                      ],
                    ),
                    const Divider(color: CampusColors.border),
                    Text(
                      '댓글 ${snapshot.data?.length ?? 0}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AsyncContent(
                      snapshot: snapshot,
                      builder: (comments) => comments.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('첫 댓글을 남겨 보세요.'),
                            )
                          : Column(
                              children: [
                                for (final comment in comments) ...[
                                  _metadata(
                                    comment.authorId,
                                    comment.createdAt,
                                  ),
                                  const SizedBox(height: 5),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      comment.content,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                  const Divider(color: CampusColors.border),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _commentComposer(),
      ],
    ),
  );

  Widget _metadata(String authorId, DateTime createdAt) => Row(
    children: [
      Expanded(child: Text(anonymousName(authorId), style: _metaStyle)),
      const SizedBox(width: 8),
      Text(relativeTime(createdAt), style: _metaStyle),
    ],
  );

  Widget _likeButton() => StreamBuilder<Set<String>>(
    stream: _likes,
    builder: (context, snapshot) {
      final likes = snapshot.data ?? const <String>{};
      final liked = likes.contains(widget.services.repository.userId);
      final label = snapshot.hasError
          ? '공감 조회 실패'
          : '${liked ? '공감 취소' : '공감'} ${likes.length}';
      return Semantics(
        label: label,
        button: true,
        child: TextButton.icon(
          key: const ValueKey('like'),
          onPressed: _liking || !snapshot.hasData ? null : _toggleLike,
          icon: CampusIcon(liked ? 'heart-selected' : 'heart'),
          label: Text('${likes.length}', style: _metaStyle),
        ),
      );
    },
  );

  Widget _commentComposer() => ColoredBox(
    color: CampusColors.surface,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              spacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 128),
                  child: OutlinedButton(
                    onPressed: _sending
                        ? null
                        : _originalComment != null
                        ? _undoCommentCorrection
                        : widget.services.correction.isAvailable &&
                              _comment.text.trim().isNotEmpty
                        ? _correctComment
                        : null,
                    child: Text(_originalComment == null ? '교정하기' : '교정 되돌리기'),
                  ),
                ),
                Expanded(
                  child: Text(
                    _commentFailed
                        ? '댓글을 등록하지 못했어요.'
                        : widget.services.correction.isAvailable
                        ? '댓글을 입력하면 교정할 수 있어요.'
                        : '댓글 교정은 준비 중이에요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _commentFailed
                          ? CampusColors.error
                          : CampusColors.secondaryInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('comment-content'),
                    controller: _comment,
                    enabled: !_sending,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(hintText: '댓글을 남겨주세요'),
                    validator: (value) => validateContent(
                      value ?? '',
                      maxLength: maxCommentLength,
                    ),
                    onChanged: (_) => setState(() => _originalComment = null),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('send-comment'),
                  onPressed: _sending || _comment.text.trim().isEmpty
                      ? null
                      : _sendComment,
                  child: Text(
                    _sending ? '등록 중' : (_commentFailed ? '다시 등록' : '등록'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.post,
    required this.initialIndex,
    required this.count,
  });

  final FeedPost post;
  final int initialIndex;
  final int count;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('이미지 확대'),
      leading: const CampusBackButton(),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(anonymousName(widget.post.authorId), style: _metaStyle),
            if (widget.post.title case final title?)
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Expanded(
              child: InteractiveViewer(
                key: ValueKey(_index),
                child: Center(
                  child: postPhoto(widget.post, _index, fit: BoxFit.contain),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: '이전 사진',
                  onPressed: _index == 0
                      ? null
                      : () => setState(() => _index--),
                  icon: const CampusIcon('back'),
                ),
                Text('${_index + 1} / ${widget.count}', style: _metaStyle),
                IconButton(
                  tooltip: '다음 사진',
                  onPressed: _index + 1 == widget.count
                      ? null
                      : () => setState(() => _index++),
                  icon: const CampusIcon('chevron-right'),
                ),
              ],
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    ),
  );
}

const _metaStyle = TextStyle(fontSize: 12, color: CampusColors.secondaryInk);
