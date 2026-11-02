import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../core/validation.dart';
import '../../widgets/async_content.dart';

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
    appBar: AppBar(title: const Text('게시글 상세')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.board.name,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          '${anonymousName(widget.post.authorId)} · ${relativeTime(widget.post.createdAt)}',
        ),
        const SizedBox(height: 24),
        SelectableText(
          widget.post.content,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            StreamBuilder<Set<String>>(
              stream: _likes,
              builder: (context, snapshot) {
                final likes = snapshot.data ?? <String>{};
                final liked = likes.contains(widget.services.repository.userId);
                return OutlinedButton.icon(
                  key: const ValueKey('like'),
                  onPressed: _liking || snapshot.hasError ? null : _toggleLike,
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                  label: Text(
                    snapshot.hasError ? '공감 조회 실패' : '공감 ${likes.length}',
                  ),
                );
              },
            ),
            const Spacer(),
            TextButton.icon(
              key: const ValueKey('report'),
              onPressed: _reporting || _reported ? null : _report,
              icon: const Icon(Icons.flag_outlined),
              label: Text(_reported ? '신고 접수됨' : '신고'),
            ),
          ],
        ),
        const Divider(height: 40),
        Text('댓글', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        StreamBuilder<List<FeedComment>>(
          stream: _comments,
          builder: (context, snapshot) => AsyncContent(
            snapshot: snapshot,
            builder: (comments) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('첫 댓글을 남겨 보세요.'),
                  ),
                for (final comment in comments)
                  Card(
                    child: ListTile(
                      title: Text(comment.content),
                      subtitle: Text(
                        '${anonymousName(comment.authorId)} · ${relativeTime(comment.createdAt)}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('comment-content'),
                controller: _comment,
                enabled: !_sending,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '댓글을 입력해 주세요.'),
                validator: (value) =>
                    validateContent(value ?? '', maxLength: maxCommentLength),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('send-comment'),
                onPressed: _sending ? null : _sendComment,
                child: Text(_sending ? '저장 중…' : '댓글 등록'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
