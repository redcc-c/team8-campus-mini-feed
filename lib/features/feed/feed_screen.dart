import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../data/demo_repository.dart';
import '../../widgets/campus_style.dart';
import '../boards/board_screen.dart';
import '../boards/create_board_screen.dart';
import '../posts/compose_screen.dart';
import '../posts/detail_screen.dart';
import '../posts/post_report.dart';
import 'feed_bookmarks.dart';
import 'popular_ranking.dart';
import 'post_card.dart';

enum _FeedTab {
  latest('최신 홈', 'home-outline', 'home'),
  popular('인기글', 'popular', 'popular'),
  bookmarks('북마크', 'bookmark', 'bookmark-nav-selected'),
  boards('게시판', 'boards', 'boards-selected');

  const _FeedTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final String icon;
  final String selectedIcon;
}

enum _Period {
  day('오늘'),
  week('이번 주'),
  month('이번 달');

  const _Period(this.label);
  final String label;

  DateTime start(DateTime now) => switch (this) {
    day => DateUtils.dateOnly(now),
    week => DateTime(now.year, now.month, now.day - now.weekday + 1),
    month => DateTime(now.year, now.month),
  };
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    required this.services,
    this.board,
    this.bookmarks,
    super.key,
  });

  final AppServices services;
  final Board? board;
  final FeedBookmarks? bookmarks;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late var _boards = widget.services.repository.watchBoards();
  late var _posts = widget.services.repository.watchPosts(widget.board?.id);
  late final _bookmarks = widget.bookmarks ?? FeedBookmarks();
  final _scroll = ScrollController();
  bool _refreshFailed = false;
  _FeedTab _tab = _FeedTab.latest;
  _Period _period = _Period.day;
  String? _filter;
  bool _onlyNotices = false;

  bool get _isHome => widget.board == null;
  bool get _showCompose =>
      !_isHome || _tab == _FeedTab.latest || _tab == _FeedTab.boards;

  @override
  void dispose() {
    if (widget.bookmarks == null) _bookmarks.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _chooseFilter(String? id) {
    setState(() => _filter = id);
    _scrollToTop();
  }

  void _chooseTab(_FeedTab tab) {
    _scrollToTop();
    setState(() => _tab = tab);
  }

  void _retry() {
    setState(() {
      _refreshFailed = false;
      _boards = widget.services.repository.watchBoards();
      _posts = widget.services.repository.watchPosts(widget.board?.id);
    });
  }

  Future<void> _refresh() async {
    final repository = widget.services.repository;
    try {
      await Future.wait([
        repository.watchBoards().first,
        repository.watchPosts(widget.board?.id).first,
      ]).timeout(const Duration(seconds: 10));
      if (mounted) _retry();
    } catch (_) {
      if (mounted) setState(() => _refreshFailed = true);
    }
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
    setState(() {
      if (_isHome) {
        _tab = _FeedTab.latest;
        if (_filter != null && _filter != post.boardId) _filter = null;
      }
      _onlyNotices = false;
    });
    _scrollToTop();
  }

  void _openPost(Board board, FeedPost post, {bool showPhoto = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(
          services: widget.services,
          board: board,
          post: post,
          bookmarks: _bookmarks,
          showPhoto: showPhoto,
        ),
      ),
    );
  }

  void _openBoard(Board board) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FeedScreen(
        services: widget.services,
        board: board,
        bookmarks: _bookmarks,
      ),
    ),
  );

  Future<void> _createBoard(DemoCommunityRepository repository) async {
    final board = await Navigator.of(context).push<Board>(
      MaterialPageRoute(
        builder: (_) => CreateBoardScreen(repository: repository),
      ),
    );
    if (mounted && board != null) _openBoard(board);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _bookmarks,
    builder: (context, _) => StreamBuilder<List<Board>>(
      stream: _boards,
      builder: (context, boardSnapshot) => StreamBuilder<List<FeedPost>>(
        stream: _posts,
        builder: (context, postSnapshot) {
          final boards = boardSnapshot.data ?? const <Board>[];
          final byId = {for (final board in boards) board.id: board};
          final board = widget.board;
          return Scaffold(
            appBar: AppBar(
              title: Text(board?.name ?? _tab.label),
              leading: _isHome ? null : const CampusBackButton(),
              titleSpacing: _isHome ? 16 : 8,
              actions: [
                if (board != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: CampusBookmarkButton(
                      selected: _bookmarks.hasBoard(board.id),
                      onPressed: () => _bookmarks.toggleBoard(board.id),
                    ),
                  ),
              ],
            ),
            floatingActionButton:
                !boardSnapshot.hasData || boards.isEmpty || !_showCompose
                ? null
                : FloatingActionButton(
                    key: const ValueKey('compose'),
                    tooltip: '글쓰기',
                    shape: const CircleBorder(),
                    elevation: 2,
                    backgroundColor: CampusColors.primary,
                    onPressed: () => _compose(boards, board ?? byId[_filter]),
                    child: const CampusIcon('compose'),
                  ),
            bottomNavigationBar: _isHome ? _navigation() : null,
            body: _body(boardSnapshot, postSnapshot, byId),
          );
        },
      ),
    ),
  );

  Widget _body(
    AsyncSnapshot<List<Board>> boardSnapshot,
    AsyncSnapshot<List<FeedPost>> postSnapshot,
    Map<String, Board> byId,
  ) {
    if (boardSnapshot.hasError || postSnapshot.hasError) {
      return CampusStatus(
        icon: 'feed-error',
        title: '인터넷 연결을 확인해 주세요',
        message: '연결이 불안정해서 불러오지 못했어요.',
        actionLabel: '다시 시도',
        onAction: _retry,
      );
    }
    if (boardSnapshot.connectionState == ConnectionState.waiting ||
        postSnapshot.connectionState == ConnectionState.waiting ||
        !boardSnapshot.hasData ||
        !postSnapshot.hasData) {
      return const _LoadingFeed();
    }
    final posts = postSnapshot.requireData;
    final boards = boardSnapshot.requireData;
    if (!_isHome) {
      final visible = _onlyNotices
          ? posts.where((post) => post.isNotice).toList()
          : posts;
      return _list(
        posts: visible,
        byId: byId,
        header: _boardHeader(widget.board!, posts.length),
        showPhotos: true,
        empty: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CampusStatus(
            icon: 'feed-empty',
            title: '아직 글이 없어요',
            message: '첫 이야기를 남겨 보세요.',
          ),
        ),
      );
    }
    switch (_tab) {
      case _FeedTab.latest:
        final visible = _filter == null
            ? posts
            : posts.where((post) => post.boardId == _filter).toList();
        if (visible.isEmpty) {
          return CampusStatus(
            icon: 'feed-empty',
            title: '조건에 맞는 글이 없어요',
            message: '다른 조건으로 찾아볼까요?',
            actionLabel: '필터 초기화',
            onAction: () => _chooseFilter(null),
          );
        }
        return Column(
          children: [
            if (_refreshFailed)
              ColoredBox(
                color: CampusColors.errorSoft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      const CampusIcon('write-error', size: 24),
                      const Expanded(
                        child: Text(
                          '불러오지 못했어요. 연결을 확인해 주세요.',
                          style: TextStyle(color: CampusColors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _list(
                  posts: visible,
                  byId: byId,
                  header: _latestHeader(
                    boards,
                    visible.any((post) => post.pending),
                  ),
                ),
              ),
            ),
          ],
        );
      case _FeedTab.popular:
        final start = _period.start(DateTime.now());
        return PopularRanking(
          repository: widget.services.repository,
          posts: posts
              .where((post) => !post.createdAt.toLocal().isBefore(start))
              .toList(),
          builder: (ranked) => _list(
            posts: ranked,
            byId: byId,
            header: _popularHeader(),
            showPhotos: true,
            empty: const CampusStatus(
              icon: 'feed-empty',
              title: '이 기간의 글이 없어요',
              message: '다른 기간을 선택해 주세요.',
            ),
          ),
        );
      case _FeedTab.bookmarks:
        final byPostId = {for (final post in posts) post.id: post};
        final saved = [
          for (final id in _bookmarks.recentPostIds) ?byPostId[id],
        ];
        if (saved.isEmpty) {
          return CampusStatus(
            icon: 'bookmark-empty',
            title: '저장한 글이 없어요',
            message: '마음에 드는 글의 책갈피 아이콘을 누르면 여기에 모여요.',
            actionLabel: '글 둘러보기',
            onAction: () => _chooseTab(_FeedTab.latest),
          );
        }
        return _list(
          posts: saved,
          byId: byId,
          showPhotos: true,
          header: Row(
            children: [
              Expanded(
                child: Text(
                  '저장한 글 ${saved.length}개',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Text('최근 저장순', style: _metaStyle),
            ],
          ),
        );
      case _FeedTab.boards:
        final repository = widget.services.repository;
        return BoardScreen(
          boards: boards,
          posts: posts,
          onOpen: _openBoard,
          onCreate: repository is DemoCommunityRepository
              ? () => _createBoard(repository)
              : null,
        );
    }
  }

  Widget _list({
    required List<FeedPost> posts,
    required Map<String, Board> byId,
    required Widget header,
    bool showPhotos = false,
    Widget? empty,
  }) {
    final indexById = {for (final (i, post) in posts.indexed) post.id: i + 1};
    return ListView.builder(
      key: ValueKey(
        _tab == _FeedTab.latest ? 'feed-list' : 'feed-${_tab.name}',
      ),
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, _showCompose ? 88 : 16),
      itemCount: posts.isEmpty && empty != null ? 2 : posts.length + 1,
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? indexById[key.value] : null,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: header,
          );
        }
        if (posts.isEmpty) return empty;
        final post = posts[index - 1];
        final board =
            byId[post.boardId] ??
            widget.board ??
            Board(id: post.boardId, name: '게시판', description: '');
        return Padding(
          key: ValueKey(post.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: PostCard(
            key: ValueKey('post-${post.id}'),
            board: board,
            post: post,
            repository: widget.services.repository,
            bookmarked: _bookmarks.hasPost(post.id),
            showPhoto: showPhotos,
            onBookmark: () => _bookmarks.togglePost(post.id),
            onMenu: () =>
                openPostReport(context, widget.services.repository, post.id),
            onOpen: () => _openPost(board, post, showPhoto: showPhotos),
          ),
        );
      },
    );
  }

  Widget _latestHeader(List<Board> boards, bool hasPending) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Row(
        spacing: 8,
        children: [
          const CampusIcon('shield'),
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
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 6,
          children: [
            CampusChoice(
              key: const ValueKey('filter-all'),
              label: '전체',
              selected: _filter == null,
              onTap: () => _chooseFilter(null),
            ),
            for (final board in boards)
              CampusChoice(
                key: ValueKey('filter-${board.id}'),
                label: board.shortName,
                selected: _filter == board.id,
                onTap: () => _chooseFilter(board.id),
              ),
          ],
        ),
      ),
      const Row(
        children: [
          Expanded(child: Text('새로운 이야기', style: _headingStyle)),
          Text('최신순', style: _metaStyle),
        ],
      ),
      if (hasPending)
        const Text(
          '서버에 전송하고 있어요.',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
    ],
  );

  Widget _popularHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Row(
        spacing: 8,
        children: [
          for (final period in _Period.values)
            Expanded(
              child: CampusChoice(
                label: period.label,
                selected: _period == period,
                onTap: () {
                  setState(() => _period = period);
                  _scrollToTop();
                },
              ),
            ),
        ],
      ),
      Text('${_period.label} 가장 공감받은 이야기', style: _headingStyle),
      const Text('좋아요순', style: _metaStyle),
    ],
  );

  Widget _boardHeader(Board board, int postCount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Text(
        board.description,
        style: const TextStyle(fontSize: 15, color: CampusColors.secondaryInk),
      ),
      Text(
        '게시글 $postCount · 즐겨찾기 ${_bookmarks.hasBoard(board.id) ? 1 : 0}',
        style: _metaStyle,
      ),
      Row(
        spacing: 8,
        children: [
          SizedBox(
            width: 104,
            child: CampusChoice(
              label: '전체글',
              selected: !_onlyNotices,
              onTap: () => setState(() => _onlyNotices = false),
            ),
          ),
          SizedBox(
            width: 84,
            child: CampusChoice(
              label: '공지',
              selected: _onlyNotices,
              onTap: () => setState(() => _onlyNotices = true),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _navigation() => NavigationBar(
    height: 64,
    backgroundColor: CampusColors.surface,
    indicatorColor: CampusColors.primarySoft,
    indicatorShape: const StadiumBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.w500,
        color: states.contains(WidgetState.selected)
            ? CampusColors.onPrimarySoft
            : CampusColors.secondaryInk,
      ),
    ),
    selectedIndex: _tab.index,
    onDestinationSelected: (index) => _chooseTab(_FeedTab.values[index]),
    destinations: [
      for (final tab in _FeedTab.values)
        NavigationDestination(
          icon: CampusIcon(tab.icon),
          selectedIcon: CampusIcon(
            tab.selectedIcon,
            color: CampusColors.onPrimarySoft,
          ),
          label: tab.label,
        ),
    ],
  );
}

class _LoadingFeed extends StatelessWidget {
  const _LoadingFeed();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '게시글을 불러오고 있어요',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final height in [216.0, 192.0, 192.0])
          Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CampusColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                _line(200, 16),
                _line(272, 24),
                _line(double.infinity, 21),
                _line(120, 48),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _line(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: CampusColors.muted,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

const _headingStyle = TextStyle(
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w600,
);
const _metaStyle = TextStyle(
  fontSize: 12,
  height: 16 / 12,
  color: CampusColors.tertiaryInk,
);
