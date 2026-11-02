class Board {
  const Board({
    required this.id,
    required this.name,
    required this.description,
  });
  final String id;
  final String name;
  final String description;
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.boardId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });
  final String id;
  final String boardId;
  final String authorId;
  final String content;
  final DateTime createdAt;
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;
}

enum ReportReason {
  spam('스팸·광고'),
  abuse('욕설·비방'),
  inappropriate('부적절한 콘텐츠'),
  other('기타');

  const ReportReason(this.label);
  final String label;
}

String anonymousName(String uid) =>
    '익명(${uid.length > 4 ? uid.substring(uid.length - 4) : uid})';

String relativeTime(DateTime createdAt, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(createdAt);
  if (age.isNegative || age.inMinutes < 1) return '방금 전';
  if (age.inHours < 1) return '${age.inMinutes}분 전';
  if (age.inDays < 1) return '${age.inHours}시간 전';
  return '${age.inDays}일 전';
}
