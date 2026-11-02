/// Offsets use Dart UTF-16 indices. originalText is the immutable checked snapshot.
class CorrectionSuggestion {
  const CorrectionSuggestion({
    required this.start,
    required this.end,
    required this.replacement,
    required this.reason,
  });
  final int start;
  final int end;
  final String replacement;
  final String reason;
}

class CorrectionResult {
  const CorrectionResult({
    required this.originalText,
    required this.suggestions,
  });
  final String originalText;
  final List<CorrectionSuggestion> suggestions;
  String apply(CorrectionSuggestion suggestion) {
    if (suggestion.start < 0 ||
        suggestion.end < suggestion.start ||
        suggestion.end > originalText.length) {
      throw RangeError('교정 제안의 원문 범위가 올바르지 않습니다.');
    }
    return originalText.replaceRange(
      suggestion.start,
      suggestion.end,
      suggestion.replacement,
    );
  }
}

abstract interface class CorrectionService {
  bool get isAvailable;
  Future<CorrectionResult> check(String text);
}

/// No model yet: never fabricate AI output or send writing to a cloud service.
class UnavailableCorrectionService implements CorrectionService {
  const UnavailableCorrectionService();
  @override
  bool get isAvailable => false;
  @override
  Future<CorrectionResult> check(String text) =>
      Future.error(UnsupportedError('이 기기의 AI 교정 모델이 아직 연결되지 않았습니다.'));
}
