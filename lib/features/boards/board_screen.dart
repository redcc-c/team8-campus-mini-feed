import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../widgets/campus_style.dart';

class BoardScreen extends StatelessWidget {
  const BoardScreen({
    required this.boards,
    required this.posts,
    required this.onOpen,
    required this.onCreate,
    super.key,
  });

  final List<Board> boards;
  final List<FeedPost> posts;
  final ValueChanged<Board> onOpen;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final basic = boards.where((board) => ['dev', 'free'].contains(board.id));
    final community = boards.where(
      (board) => !['dev', 'free'].contains(board.id),
    );
    final counts = <String, int>{};
    final startOfDay = DateUtils.dateOnly(DateTime.now());
    for (final post in posts) {
      if (!post.createdAt.isBefore(startOfDay)) {
        counts.update(post.boardId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        OutlinedButton(onPressed: onCreate, child: const Text('새 게시판 만들기')),
        if (basic.isNotEmpty) ...[
          _heading('기본 게시판'),
          for (final board in [...basic]..sort((a, b) => a.id.compareTo(b.id)))
            _row(board, counts[board.id] ?? 0),
        ],
        if (community.isNotEmpty) ...[
          _heading('사용자 게시판'),
          for (final board in community) _row(board, counts[board.id] ?? 0),
        ],
      ],
    );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );

  Widget _row(Board board, int count) => Column(
    children: [
      Material(
        color: CampusColors.surface,
        child: ListTile(
          key: ValueKey('board-${board.id}'),
          minTileHeight: 78,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          title: Text(
            board.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            board.description,
            style: const TextStyle(
              fontSize: 13,
              color: CampusColors.secondaryInk,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                '새 글 $count',
                style: const TextStyle(
                  fontSize: 12,
                  color: CampusColors.tertiaryInk,
                ),
              ),
              const CampusIcon('chevron-right'),
            ],
          ),
          onTap: () => onOpen(board),
        ),
      ),
      const Divider(height: 16, thickness: 1, color: CampusColors.border),
    ],
  );
}
