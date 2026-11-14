import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';
import '../core/validation.dart';
import 'community_repository.dart';

/// Emulator adapter. Production bootstrap is a separate team task.
class FirebaseCommunityRepository
    implements CommunityRepository, PostAvailability {
  FirebaseCommunityRepository({
    required FirebaseFirestore firestore,
    required this.userId,
  }) : _db = firestore;
  final FirebaseFirestore _db;
  @override
  final String userId;
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');
  DateTime _date(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime.now();

  @override
  Stream<bool> watchPostAvailability(String postId) => _posts
      .doc(postId)
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => snapshot.exists || !snapshot.metadata.isFromCache)
      .map((snapshot) => snapshot.exists);

  @override
  Stream<List<Board>> watchBoards() => _db
      .collection('boards')
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => Board(
                id: doc.id,
                name: doc.data()['name'] as String,
                description: doc.data()['description'] as String,
              ),
            )
            .toList(),
      );
  @override
  Stream<List<FeedPost>> watchPosts([String? boardId]) =>
      (boardId == null ? _posts : _posts.where('boardId', isEqualTo: boardId))
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return FeedPost(
                id: doc.id,
                boardId: data['boardId'] as String,
                authorId: data['authorId'] as String,
                content: data['content'] as String,
                title: data['title'] as String?,
                createdAt: _date(data['createdAt']),
                isNotice: data['isNotice'] == true,
                pending: doc.metadata.hasPendingWrites,
              );
            }).toList(),
          );
  @override
  Stream<List<FeedComment>> watchComments(String postId) => _posts
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return FeedComment(
            id: doc.id,
            postId: postId,
            authorId: data['authorId'] as String,
            content: data['content'] as String,
            createdAt: _date(data['createdAt']),
          );
        }).toList(),
      );
  @override
  Stream<Set<String>> watchLikes(String postId) => _posts
      .doc(postId)
      .collection('likes')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

  @override
  Future<FeedPost> createPost({
    required String boardId,
    required String content,
    String? title,
  }) async {
    final validated = requireContent(content);
    final validatedTitle = title == null
        ? null
        : requireContent(title, maxLength: maxTitleLength);
    final doc = _posts.doc();
    await doc.set({
      'boardId': boardId,
      'authorId': userId,
      'content': validated,
      'title': ?validatedTitle,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return FeedPost(
      id: doc.id,
      boardId: boardId,
      authorId: userId,
      content: validated,
      title: validatedTitle,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> addComment({required String postId, required String content}) =>
      _posts
          .doc(postId)
          .collection('comments')
          .add({
            'authorId': userId,
            'content': requireContent(content, maxLength: maxCommentLength),
            'createdAt': FieldValue.serverTimestamp(),
          })
          .then((_) {});
  @override
  Future<void> toggleLike(String postId) async {
    final ref = _posts.doc(postId).collection('likes').doc(userId);
    await _db.runTransaction((transaction) async {
      final like = await transaction.get(ref);
      if (like.exists) {
        transaction.delete(ref);
      } else {
        transaction.set(ref, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> reportPost({
    required String postId,
    required ReportReason reason,
    String? details,
  }) => _posts.doc(postId).collection('reports').doc(userId).set({
    'reporterId': userId,
    'reason': reason.name,
    'details': ?details,
    'createdAt': FieldValue.serverTimestamp(),
  });
  @override
  Future<void> dispose() async {}
}
