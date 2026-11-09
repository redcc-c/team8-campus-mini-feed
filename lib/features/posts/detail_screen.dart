import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../core/validation.dart';
import '../../widgets/async_content.dart';
import '../../widgets/campus_style.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    required this.services,
    required this.board,
    required this.post,
    super.key,
  });
  final AppServices services;
  final Board board;
  final FeedPost post;
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
  bool _sending = false;
  bool _liking = false;
  bool _reporting = false;
  bool _reported = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await widget.services.repository
          .addComment(postId: widget.post.id, content: _comment.text)
          .timeout(const Duration(seconds: 15));
      if (mounted) _comment.clear();
    } catch (_) {
      if (mounted) showNotice(context, '댓글을 저장하지 못했습니다. 입력 내용은 유지됩니다.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

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
    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('신고 사유를 선택해 주세요'),
        children: [
          for (final reason in ReportReason.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(reason),
              child: Text(reason.label),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _reporting = true);
    try {
      await widget.services.repository
          .reportPost(postId: widget.post.id, reason: reason)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() => _reported = true);
        showNotice(context, '신고를 접수했습니다.');
      }
    } catch (_) {
      if (mounted) {
        showNotice(context, '신고를 저장하지 못했습니다. 중복 신고 여부와 연결 상태를 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('게시글 상세'),
      leading: const CampusBackButton(),
      actions: [
        PopupMenuButton<ReportReason>(
          key: const ValueKey('report'),
          tooltip: '게시글 메뉴',
          icon: const CampusIcon('more', size: 24),
          enabled: !_reporting && !_reported,
          itemBuilder: (_) => [
            PopupMenuItem<ReportReason>(
              onTap: _report,
              child: const Text('신고하기'),
            ),
          ],
        ),
        if (MediaQuery.textScalerOf(context).scale(22) < 34)
          const IconButton(
            tooltip: '북마크 · 후속 기능',
            onPressed: null,
            icon: CampusIcon('bookmark'),
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
          icon: liked
              ? const Icon(
                  Icons.favorite,
                  size: 20,
                  color: CampusColors.primary,
                )
              : const CampusIcon('heart'),
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
            const Row(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: null, child: Text('교정하기')),
                Expanded(
                  child: Text(
                    '댓글 교정은 준비 중이에요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: CampusColors.secondaryInk,
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('send-comment'),
                  onPressed: _sending || _comment.text.trim().isEmpty
                      ? null
                      : _sendComment,
                  child: Text(_sending ? '저장 중…' : '등록'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

const _metaStyle = TextStyle(fontSize: 12, color: CampusColors.secondaryInk);
