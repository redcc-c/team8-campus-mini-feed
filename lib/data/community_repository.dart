import '../core/models.dart';

/// Screens depend on this contract, not directly on Firebase plugins.
abstract interface class CommunityRepository {
  String get userId;
  Stream<List<Board>> watchBoards();
  Stream<List<FeedPost>> watchPosts([String? boardId]);
  Stream<List<FeedComment>> watchComments(String postId);
  Stream<Set<String>> watchLikes(String postId);
  Future<FeedPost> createPost({
    required String boardId,
    required String content,
    String? title,
  });
  Future<void> addComment({required String postId, required String content});
  Future<void> toggleLike(String postId);
  Future<void> reportPost({
    required String postId,
    required ReportReason reason,
    String? details,
  });
  Future<void> dispose();
}

abstract interface class PostAvailability {
  Stream<bool> watchPostAvailability(String postId);
}
