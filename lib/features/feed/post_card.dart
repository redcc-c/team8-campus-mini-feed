import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/community_repository.dart';
import '../../widgets/async_content.dart';
import '../../widgets/campus_style.dart';
import '../posts/post_photo.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    required this.board,
    required this.post,
    required this.repository,
    required this.onOpen,
    required this.onMenu,
    required this.onBookmark,
    required this.bookmarked,
    this.showPhoto = false,
    super.key,
  });

  final Board board;
  final FeedPost post;
  final CommunityRepository repository;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final VoidCallback onBookmark;
  final bool bookmarked;
  final bool showPhoto;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late final _likes = widget.repository.watchLikes(widget.post.id);
  late final _comments = widget.repository.watchComments(widget.post.id);
  bool _liking = false;

  Future<void> _toggleLike() async {
    setState(() => _liking = true);
    try {
      await widget.repository
          .toggleLike(widget.post.id)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted) showNotice(context, '공감을 반영하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    const radius = BorderRadius.all(Radius.circular(12));
    return Card(
      color: CampusColors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: CampusColors.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 24,
                      maxWidth: 86,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: CampusColors.muted,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Text(
                        widget.board.shortName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CampusColors.onPrimarySoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 18 / 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    flex: 3,
                    child: Text(
                      anonymousName(post.authorId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CampusColors.secondaryInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: Text(
                      post.pending ? '전송 중' : relativeTime(post.createdAt),
                      textAlign: TextAlign.end,
                      style: _metaStyle,
                    ),
                  ),
                  IconButton(
                    tooltip: '게시글 메뉴',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 34,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onMenu,
                    icon: const CampusIcon('more', size: 24),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        if (post.title case final title?)
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          post.content
                              .split('\n\n')
                              .first
                              .replaceAll(RegExp(r'\s+'), ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: CampusColors.secondaryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (postPhotoCount(post, showSample: widget.showPhoto) > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: postPhoto(
                        post,
                        0,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StreamBuilder<Set<String>>(
                    stream: _likes,
                    builder: (context, snapshot) {
                      final likes = snapshot.data ?? const <String>{};
                      final liked = likes.contains(widget.repository.userId);
                      return _action(
                        icon: CampusIcon(liked ? 'heart-selected' : 'heart'),
                        count: likes.length,
                        label: liked ? '공감 취소' : '공감',
                        onTap: _liking || !snapshot.hasData
                            ? null
                            : _toggleLike,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<List<FeedComment>>(
                    stream: _comments,
                    builder: (context, snapshot) => _action(
                      icon: const CampusIcon('comment'),
                      count: snapshot.data?.length ?? 0,
                      label: '댓글',
                      onTap: widget.onOpen,
                    ),
                  ),
                  const Spacer(),
                  CampusBookmarkButton(
                    selected: widget.bookmarked,
                    onPressed: widget.onBookmark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action({
    required Widget icon,
    required int count,
    required String label,
    required VoidCallback? onTap,
  }) => Semantics(
    button: true,
    label: '$label $count',
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              icon,
              Text('$count', style: _metaStyle),
            ],
          ),
        ),
      ),
    ),
  );
}

const _metaStyle = TextStyle(fontSize: 12, color: CampusColors.secondaryInk);
