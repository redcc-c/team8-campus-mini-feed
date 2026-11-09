import 'dart:async';

import '../core/models.dart';
import '../core/validation.dart';
import 'community_repository.dart';

class DemoCommunityRepository implements CommunityRepository {
  DemoCommunityRepository({bool seed = true}) {
    if (seed) _seed();
  }

  static const boards = [
    Board(
      id: 'free',
      name: '캠퍼스 일상',
      shortName: '일상',
      description: '학교에서 만나는 소소한 이야기',
    ),
    Board(
      id: 'study',
      name: '함께 공부해요',
      shortName: '공부',
      description: '스터디와 공부 기록을 공유해요',
    ),
    Board(
      id: 'dev',
      name: '개발자 광장',
      shortName: '개발',
      description: '개발 공부와 진로 이야기를 나눠요',
    ),
    Board(
      id: 'hobby',
      name: '동아리 소식',
      shortName: '동아리',
      description: '새로운 모임과 활동 소식이에요',
    ),
  ];
  final _changes = StreamController<void>.broadcast();
  final _posts = <FeedPost>[];
  final _comments = <FeedComment>[];
  final _likes = <String, Set<String>>{};
  final _reported = <String>{};
  int _sequence = 0;
  @override
  String get userId => 'demo-local-f8c2';

  void _seed() {
    final now = DateTime.now();
    final samples = [
      (
        'welcome',
        'dev',
        'demo-user-7b3d',
        5,
        '수업용 노트북, 어떤 모델 쓰세요?',
        '앱 개발과 과제용으로 고민 중이에요. 사용 후기를 들려주세요.\n\n'
            '주로 Flutter로 앱을 만들고 문서 작업도 할 예정이에요. 사용해 본 분들의 이야기가 궁금해요.',
      ),
      (
        'library',
        'free',
        userId,
        18,
        '도서관 조용한 자리 추천해요',
        '오늘 3층 창가 자리가 한적해요. 같이 공부하실 분 있나요?',
      ),
      (
        'clubs',
        'hobby',
        'demo-user-c3d2',
        60,
        '이번 주 동아리 모집 일정 모음',
        '관심 있는 모임을 찾는 분들을 위해 이번 주 일정을 정리했어요.',
      ),
      (
        'study',
        'study',
        'demo-user-a29e',
        72,
        '저녁 스터디 같이 하실 분?',
        '기초 알고리즘 문제를 한 문제씩 풀고 풀이를 나눠요.',
      ),
      (
        'walk',
        'free',
        'demo-user-c3d2',
        95,
        '수업 끝나고 캠퍼스 한 바퀴',
        '날씨가 좋아서 잠깐 걸었어요. 마음에 드는 산책길이 있나요?',
      ),
      (
        'flutter',
        'dev',
        'demo-user-7b3d',
        120,
        'Flutter 위젯 공부 기록',
        '목록에서 상세로 이동하는 작은 예제를 만들어 봤어요.',
      ),
      (
        'reading',
        'hobby',
        'demo-user-a29e',
        170,
        '이번 달 독서 모임',
        '부담 없이 읽은 책 한 권을 소개하는 모임을 열어요.',
      ),
      (
        'notes',
        'study',
        'demo-user-c3d2',
        200,
        '팀플 회의록은 어떻게 정리해요?',
        '결정한 내용과 다음 할 일을 나눠 적으니 찾기 편했어요.',
      ),
      (
        'lunch',
        'free',
        userId,
        280,
        '점심시간에 잠깐 쉬기 좋은 곳',
        '사람이 덜 지나는 곳에서 책을 읽고 왔어요.',
      ),
      (
        'debug',
        'dev',
        'demo-user-a29e',
        340,
        '작은 버그를 고친 기록',
        '재현 순서를 먼저 적어 두니 원인을 빨리 찾을 수 있었어요.',
      ),
    ];
    for (final (id, boardId, authorId, minutes, title, content) in samples) {
      _posts.add(
        FeedPost(
          id: id,
          boardId: boardId,
          authorId: authorId,
          title: title,
          content: content,
          createdAt: now.subtract(Duration(minutes: minutes)),
        ),
      );
    }
    _comments.addAll([
      FeedComment(
        id: 'sample-comment-1',
        postId: 'welcome',
        authorId: 'demo-user-c3d2',
        content: '저는 가벼운 모델을 쓰고 있어요. 강의실 이동할 때 무게 차이가 꽤 커요.',
        createdAt: now.subtract(const Duration(minutes: 3)),
      ),
      FeedComment(
        id: 'sample-comment-2',
        postId: 'welcome',
        authorId: 'demo-user-a29e',
        content: '메모리 16GB 이상이면 과제할 때 편하더라고요!',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
    for (final (id, count) in [
      ('welcome', 42),
      ('library', 26),
      ('clubs', 19),
    ]) {
      _likes[id] = {for (var i = 0; i < count; i++) 'sample-like-$i'};
    }
  }

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
  Stream<List<FeedPost>> watchPosts([String? boardId]) => _watch(() {
    final posts =
        _posts
            .where((post) => boardId == null || post.boardId == boardId)
            .toList()
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
    String? title,
  }) async {
    if (!boards.any((board) => board.id == boardId)) {
      throw ArgumentError('게시판을 선택해 주세요.');
    }
    final post = FeedPost(
      id: 'local-${++_sequence}',
      boardId: boardId,
      authorId: userId,
      content: requireContent(content),
      title: title == null
          ? null
          : requireContent(title, maxLength: maxTitleLength),
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
