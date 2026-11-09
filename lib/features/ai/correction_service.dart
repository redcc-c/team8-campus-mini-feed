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
    this.checkedSegments = 0,
    this.failedSegments = 0,
  });
  final String originalText;
  final List<CorrectionSuggestion> suggestions;

  /// Segments the model answered. Failed segments are kept as written.
  final int checkedSegments;
  final int failedSegments;

  bool get allFailed => failedSegments > 0 && checkedSegments == 0;

  String apply(CorrectionSuggestion suggestion) => applyAll([suggestion]);

  /// Applies non-overlapping [selected] suggestions to [originalText].
  String applyAll(Iterable<CorrectionSuggestion> selected) {
    final sorted = [...selected]..sort((a, b) => a.start.compareTo(b.start));
    var previousEnd = 0;
    for (final suggestion in sorted) {
      if (suggestion.start < previousEnd ||
          suggestion.end < suggestion.start ||
          suggestion.end > originalText.length) {
        throw RangeError('교정 제안의 원문 범위가 올바르지 않습니다.');
      }
      previousEnd = suggestion.end;
    }
    var text = originalText;
    for (final suggestion in sorted.reversed) {
      text = text.replaceRange(
        suggestion.start,
        suggestion.end,
        suggestion.replacement,
      );
    }
    return text;
  }
}

typedef CorrectionProgress = void Function(int done, int total);

abstract interface class CorrectionService {
  bool get isAvailable;

  /// [isCancelled] stops sending further segments; [onProgress] reports
  /// checked segments after the text has been split.
  Future<CorrectionResult> check(
    String text, {
    CorrectionProgress? onProgress,
    bool Function()? isCancelled,
  });
}

/// No usable model: never fabricate AI output or send writing to a cloud service.
class UnavailableCorrectionService implements CorrectionService {
  const UnavailableCorrectionService();
  @override
  bool get isAvailable => false;
  @override
  Future<CorrectionResult> check(
    String text, {
    CorrectionProgress? onProgress,
    bool Function()? isCancelled,
  }) => Future.error(UnsupportedError('이 기기의 AI 교정 모델이 아직 연결되지 않았습니다.'));
}
