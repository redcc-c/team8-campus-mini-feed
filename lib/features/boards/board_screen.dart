import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../widgets/async_content.dart';
import '../feed/feed_screen.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({required this.services, super.key});
  final AppServices services;
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final _boards = widget.services.repository.watchBoards();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('캠퍼스 미니 피드'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Chip(
            label: Text(widget.services.isDemo ? '체험 모드' : '로컬 테스트'),
            avatar: const Icon(Icons.eco_outlined, size: 16),
          ),
        ),
      ],
    ),
    body: StreamBuilder<List<Board>>(
      stream: _boards,
      builder: (context, snapshot) => AsyncContent(
        snapshot: snapshot,
        builder: (boards) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'CAMPUS / TEAM 8',
              style: TextStyle(fontSize: 12, letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            Text(
              '작은 이야기로\n이어지는 캠퍼스',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('관심 있는 게시판을 골라 이야기를 나눠 보세요.'),
            const SizedBox(height: 24),
            if (widget.services.isDemo) ...[
              const Text('체험 모드의 글과 활동은 앱을 다시 시작하면 초기화됩니다.'),
              const SizedBox(height: 24),
            ],
            Text('게시판', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (boards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('아직 게시판이 없습니다. 로컬 테스트 데이터를 준비해 주세요.'),
              ),
            for (final board in boards)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    key: ValueKey('board-${board.id}'),
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      child: Icon(Icons.forum_outlined),
                    ),
                    title: Text(
                      board.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(board.description),
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            FeedScreen(services: widget.services, board: board),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              '${anonymousName(widget.services.repository.userId)} · 서로를 존중하는 대화',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
