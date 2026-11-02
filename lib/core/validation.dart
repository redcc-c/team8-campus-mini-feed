const maxPostLength = 500;
const maxCommentLength = 200;

// Count Unicode code points, matching Firestore rules. AI tokens are a separate unit.
String? validateContent(String value, {int maxLength = maxPostLength}) {
  if (value.trim().isEmpty) return '내용을 입력해 주세요.';
  if (value.runes.length > maxLength) return '$maxLength자 이내로 입력해 주세요.';
  return null;
}

String requireContent(String value, {int maxLength = maxPostLength}) {
  final error = validateContent(value, maxLength: maxLength);
  if (error != null) throw ArgumentError(error);
  return value.trim();
}
