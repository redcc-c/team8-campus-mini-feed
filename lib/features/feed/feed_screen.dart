import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../widgets/async_content.dart';
import '../../widgets/campus_style.dart';
import '../boards/board_screen.dart';
import '../posts/compose_screen.dart';
import '../posts/detail_screen.dart';
import 'post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({required this.services, this.board, super.key});

  final AppServices services;
  final Board? board;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final _boards = widget.services.repository.watchBoards();
  late final _posts = widget.services.repository.watchPosts(widget.board?.id);
  final _scroll = ScrollController();
  String? _filter;

  bool get _isHome => widget.board == null;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _chooseFilter(String? id) {
    setState(() => _filter = id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _compose(List<Board> boards, Board? selected) async {
    final post = await Navigator.of(context).push<FeedPost>(
      MaterialPageRoute(
        builder: (_) => ComposeScreen(
          services: widget.services,
          board: selected,
          boards: boards,
        ),
      ),
    );
    if (!mounted || post == null) return;
    if (_isHome && _filter != null && _filter != post.boardId) {
      _chooseFilter(null);
    } else if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _openPost(Board board, FeedPost post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DetailScreen(services: widget.services, board: board, post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Board>>(
    stream: _boards,
    builder: (context, boardSnapshot) {
      final boards = boardSnapshot.data ?? const <Board>[];
      final byId = {for (final board in boards) board.id: board};
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.board?.name ?? '최신 홈'),
          leading: _isHome ? null : const CampusBackButton(),
          titleSpacing: 16,
        ),
        floatingActionButton: boards.isEmpty
            ? null
            : FloatingActionButton(
                key: const ValueKey('compose'),
                tooltip: '글쓰기',
                shape: const CircleBorder(),
                backgroundColor: CampusColors.primary,
                onPressed: () =>
                    _compose(boards, widget.board ?? byId[_filter]),
                child: const CampusIcon('compose'),
              ),
        bottomNavigationBar: _isHome ? _navigation(context) : null,
        body: AsyncContent(
          snapshot: boardSnapshot,
          builder: (_) => StreamBuilder<List<FeedPost>>(
            stream: _posts,
            builder: (context, snapshot) => AsyncContent(
              snapshot: snapshot,
              builder: (posts) {
                final visible = _filter == null
                    ? posts
                    : posts.where((post) => post.boardId == _filter).toList();
                return ListView.builder(
                  key: const ValueKey('feed-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: visible.isEmpty ? 2 : visible.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _header(boards);
                    if (visible.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          '아직 글이 없어요.\n첫 이야기를 남겨 보세요.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final post = visible[index - 1];
                    final board =
                        byId[post.boardId] ??
                        widget.board ??
                        Board(id: post.boardId, name: '게시판', description: '');
                    return Padding(
                      key: ValueKey('feed-item-${post.id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PostCard(
                        key: ValueKey('post-${post.id}'),
                        board: board,
                        post: post,
                        repository: widget.services.repository,
                        onOpen: () => _openPost(board, post),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _header(List<Board> boards) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_isHome) ...[
        Row(
          children: [
            const CampusIcon('shield'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                anonymousName(widget.services.repository.userId),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CampusColors.secondaryInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              _filterButton('전체', null),
              for (final board in boards)
                _filterButton(board.shortName, board.id),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      const Row(
        children: [
          Expanded(
            child: Text(
              '새로운 이야기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '최신순',
            style: TextStyle(fontSize: 12, color: CampusColors.tertiaryInk),
          ),
        ],
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _filterButton(String label, String? id) {
    final selected = _filter == id;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('filter-${id ?? 'all'}'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => _chooseFilter(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? CampusColors.primarySoft : CampusColors.surface,
              border: Border.all(
                color: selected
                    ? CampusColors.primary
                    : CampusColors.borderStrong,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36, minWidth: 54),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) const CampusIcon('check', size: 24),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? CampusColors.onPrimarySoft
                            : CampusColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navigation(BuildContext context) => NavigationBar(
    height: 64,
    backgroundColor: CampusColors.surface,
    indicatorColor: CampusColors.primarySoft,
    onDestinationSelected: (index) {
      if (index == 3) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BoardScreen(services: widget.services),
          ),
        );
      }
    },
    destinations: const [
      NavigationDestination(icon: CampusIcon('home'), label: '최신 홈'),
      NavigationDestination(
        icon: CampusIcon('popular'),
        label: '인기글',
        enabled: false,
      ),
      NavigationDestination(
        icon: CampusIcon('bookmark'),
        label: '북마크',
        enabled: false,
      ),
      NavigationDestination(icon: CampusIcon('boards'), label: '게시판'),
    ],
  );
}
