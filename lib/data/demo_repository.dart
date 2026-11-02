import 'dart:async';

import '../core/models.dart';
import '../core/validation.dart';
import 'community_repository.dart';

class DemoCommunityRepository implements CommunityRepository {
  DemoCommunityRepository({bool seed = true}) {
    if (seed) {
      _posts.addAll([
        FeedPost(
          id: 'welcome',
          boardId: 'free',
          authorId: 'demo-user-1001',
          content: '우리 캠퍼스의 작은 이야기를 나눠요.\n게시판을 고르고 첫 글을 작성해 보세요.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        FeedPost(
          id: 'study',
          boardId: 'study',
          authorId: 'demo-user-1002',
          content: '함께 공부할 친구를 찾는 게시판입니다.\n어떤 주제를 공부하고 있나요?',
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
      ]);
    }
  }

  static const boards = [
    Board(id: 'free', name: '자유', description: '가벼운 일상과 캠퍼스 이야기'),
    Board(id: 'study', name: '공부', description: '질문과 스터디, 배움의 기록'),
    Board(id: 'hobby', name: '취미', description: '함께 즐기는 관심사와 취미'),
  ];
  final _changes = StreamController<void>.broadcast();
  final _posts = <FeedPost>[];
  final _comments = <FeedComment>[];
  final _likes = <String, Set<String>>{};
  final _reported = <String>{};
  int _sequence = 0;
  @override
  String get userId => 'demo-local-0008';

  Stream<T> _watch<T>(T Function() read) => Stream<T>.multi((sink) {
    final subscription = _changes.stream.listen(
      (_) => sink.add(read()),
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.add(read());
    sink.onCancel = subscription.cancel;
  });

  void _requirePost(String postId) {
    if (!_posts.any((post) => post.id == postId)) {
      throw StateError('게시글을 찾을 수 없습니다.');
    }
  }

  @override
  Stream<List<Board>> watchBoards() => Stream.value(boards);
  @override
  Stream<List<FeedPost>> watchPosts(String boardId) => _watch(() {
    final posts = _posts.where((post) => post.boardId == boardId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(posts);
  });
  @override
  Stream<List<FeedComment>> watchComments(String postId) => _watch(
    () => List.unmodifiable(
      _comments.where((comment) => comment.postId == postId),
    ),
  );
  @override
  Stream<Set<String>> watchLikes(String postId) =>
      _watch(() => Set.unmodifiable(_likes[postId] ?? <String>{}));

  @override
  Future<FeedPost> createPost({
    required String boardId,
    required String content,
  }) async {
    if (!boards.any((board) => board.id == boardId)) {
      throw ArgumentError('게시판을 선택해 주세요.');
    }
    final post = FeedPost(
      id: 'local-${++_sequence}',
      boardId: boardId,
      authorId: userId,
      content: requireContent(content),
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    _changes.add(null);
    return post;
  }

  @override
  Future<void> addComment({
    required String postId,
    required String content,
  }) async {
    _requirePost(postId);
    _comments.add(
      FeedComment(
        id: 'comment-${++_sequence}',
        postId: postId,
        authorId: userId,
        content: requireContent(content, maxLength: maxCommentLength),
        createdAt: DateTime.now(),
      ),
    );
    _changes.add(null);
  }

  @override
  Future<void> toggleLike(String postId) async {
    _requirePost(postId);
    final likes = _likes.putIfAbsent(postId, () => <String>{});
    if (!likes.add(userId)) likes.remove(userId);
    _changes.add(null);
  }

  @override
  Future<void> reportPost({
    required String postId,
    required ReportReason reason,
  }) async {
    _requirePost(postId);
    if (!_reported.add(postId)) throw StateError('이미 신고한 게시글입니다.');
  }

  @override
  Future<void> dispose() => _changes.close();
}
