import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart' show StringCharacters;

import 'correction_service.dart';
import 'proofreader.dart';

/// ML Kit Proofreading accepts input under this many model tokens.
const proofreadTokenLimit = 256;

class TextPiece {
  const TextPiece(this.text, {required this.editable});

  final String text;

  /// Whether the piece is sent to the proofreader; URLs, line breaks and
  /// whitespace between pieces are kept verbatim.
  final bool editable;
}

typedef TokenCounter = Future<int> Function(String text);

final _url = RegExp(r'(?:https?://|www\.)\S+', caseSensitive: false);
final _meaningful = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}'
  r'\u{2190}-\u{21FF}\u{00A9}\u{00AE}\u{203C}\u{2049}\u{2122}\u{2139}'
  r'\u{3030}\u{303D}\u{3297}\u{3299}\u{FE0F}\u{200D}\u{20E3}]',
  unicode: true,
);
final _lineBreak = RegExp(r'\r\n|[\n\r\u2028\u2029]');
final _sentence = RegExp(r'\S.*?(?:[.!?…]+(?=\s|$)|$)');
final _word = RegExp(r'\S+');

/// Splits [input] at URL, line, sentence and word boundaries so every
/// editable piece is under [tokenLimit] tokens as counted by [countTokens].
///
/// Without a tokenizer each sentence becomes its own piece and the model's
/// own REQUEST_TOO_LARGE check decides when to split further; no character
/// count stands in for tokens.
Future<List<TextPiece>> splitForProofreading(
  String input,
  TokenCounter? countTokens, {
  int tokenLimit = proofreadTokenLimit,
}) async {
  final pieces = <TextPiece>[];

  void fixed(String text) {
    if (text.isEmpty) return;
    if (pieces.isNotEmpty && !pieces.last.editable) {
      pieces.last = TextPiece(pieces.last.text + text, editable: false);
    } else {
      pieces.add(TextPiece(text, editable: false));
    }
  }

  void prose(String text) {
    if (_meaningful.hasMatch(text)) {
      pieces.add(TextPiece(text, editable: true));
    } else {
      fixed(text);
    }
  }

  Future<bool> fits(String text) async => await countTokens!(text) < tokenLimit;

  Future<void> hardSplit(String text) async {
    var chars = text.characters.toList();
    while (chars.isNotEmpty) {
      // Longest prefix under the limit, never below one character so the
      // loop always advances.
      var low = 1;
      var high = chars.length;
      while (low < high) {
        final mid = (low + high + 1) ~/ 2;
        if (await fits(chars.sublist(0, mid).join())) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      prose(chars.sublist(0, low).join());
      chars = chars.sublist(low);
    }
  }

  List<(String, String)> units(Iterable<Match> matches, String text) {
    final result = <(String, String)>[];
    var cursor = 0;
    for (final match in matches) {
      result.add((text.substring(cursor, match.start), match.group(0)!));
      cursor = match.end;
    }
    return result;
  }

  /// Joins consecutive units while they fit; a unit that alone is too long
  /// goes to [tooLong].
  Future<void> pack(
    List<(String, String)> units,
    Future<void> Function(String unit) tooLong,
  ) async {
    var chunk = '';
    for (final (gap, unit) in units) {
      if (chunk.isNotEmpty && await fits('$chunk$gap$unit')) {
        chunk = '$chunk$gap$unit';
        continue;
      }
      if (chunk.isNotEmpty) prose(chunk);
      chunk = '';
      fixed(gap);
      if (await fits(unit)) {
        chunk = unit;
      } else {
        await tooLong(unit);
      }
    }
    if (chunk.isNotEmpty) prose(chunk);
  }

  Future<void> line(String text) async {
    final core = text.trim();
    if (!_meaningful.hasMatch(core)) {
      fixed(text);
      return;
    }
    final start = text.indexOf(core);
    fixed(text.substring(0, start));
    if (countTokens == null) {
      for (final (gap, sentence) in units(_sentence.allMatches(core), core)) {
        fixed(gap);
        prose(sentence);
      }
    } else if (await fits(core)) {
      prose(core);
    } else {
      await pack(
        units(_sentence.allMatches(core), core),
        (sentence) =>
            pack(units(_word.allMatches(sentence), sentence), hardSplit),
      );
    }
    fixed(text.substring(start + core.length));
  }

  Future<void> block(String text) async {
    var cursor = 0;
    for (final match in _lineBreak.allMatches(text)) {
      await line(text.substring(cursor, match.start));
      fixed(match.group(0)!);
      cursor = match.end;
    }
    await line(text.substring(cursor));
  }

  var cursor = 0;
  for (final match in _url.allMatches(input)) {
    await block(input.substring(cursor, match.start));
    fixed(match.group(0)!);
    cursor = match.end;
  }
  await block(input.substring(cursor));
  return pieces;
}

/// [inferenceMs] covers only the proofreading requests, not token counting.
typedef CorrectionRun = ({
  CorrectionResult result,
  int requests,
  int inferenceMs,
});

typedef _Attempt = ({String text, int failures});

class _SplitCancelled implements Exception {
  const _SplitCancelled();
}

class _Run {
  _Run(this.isCancelled);

  final bool Function()? isCancelled;
  int requests = 0;
  int inferenceMs = 0;

  /// Set after a timeout: the native request may still be running, so no
  /// further pieces are sent in this run.
  bool stalled = false;
}

class CorrectionEngine {
  CorrectionEngine(
    this.proofreader, {
    this.tokenLimit = proofreadTokenLimit,
    this.timeout = const Duration(seconds: 15),
    this.maxSplitDepth = 2,
  });

  final Proofreader proofreader;
  final int tokenLimit;
  final Duration timeout;
  final int maxSplitDepth;

  // ML Kit serves one request at a time and abandoning a Dart future does not
  // stop the native call, so each request first waits for the previous one.
  static final _inFlight = Expando<Future<void>>();

  /// Waits for a request left running by an earlier run; `false` if it is
  /// still running after [timeout].
  Future<bool> waitForIdle() async {
    try {
      await _inFlight[proofreader]?.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<CorrectionRun> correct(
    String text, {
    bool Function()? isCancelled,
    CorrectionProgress? onProgress,
  }) async {
    final TokenCounter? counter = await proofreader.canCountTokens()
        ? (piece) {
            if (isCancelled?.call() ?? false) throw const _SplitCancelled();
            return proofreader.countTokens(piece).timeout(timeout);
          }
        : null;
    final List<TextPiece> pieces;
    try {
      pieces = await splitForProofreading(
        text,
        counter,
        tokenLimit: tokenLimit,
      );
    } on _SplitCancelled {
      return (
        result: CorrectionResult(originalText: text, suggestions: const []),
        requests: 0,
        inferenceMs: 0,
      );
    }
    final total = pieces.where((piece) => piece.editable).length;
    onProgress?.call(0, total);
    final run = _Run(isCancelled);
    final suggestions = <CorrectionSuggestion>[];
    var offset = 0;
    var done = 0;
    var checked = 0;
    var failed = 0;
    for (final piece in pieces) {
      if (piece.editable && !(isCancelled?.call() ?? false)) {
        final attempt = await _attempt(run, piece.text, 0);
        failed += attempt.failures;
        if (attempt.failures == 0 || attempt.text != piece.text) checked++;
        if (attempt.text != piece.text) {
          suggestions.addAll(wordSuggestions(piece.text, attempt.text, offset));
        }
        onProgress?.call(++done, total);
      }
      offset += piece.text.length;
    }
    return (
      result: CorrectionResult(
        originalText: text,
        suggestions: List.unmodifiable(suggestions),
        checkedSegments: checked,
        failedSegments: failed,
      ),
      requests: run.requests,
      inferenceMs: run.inferenceMs,
    );
  }

  Future<_Attempt> _attempt(_Run run, String text, int depth) async {
    bool cancelled() => run.isCancelled?.call() ?? false;
    if (cancelled()) return (text: text, failures: 0);
    if (run.stalled) return (text: text, failures: 1);
    if (!await waitForIdle()) {
      run.stalled = true;
      return (text: text, failures: 1);
    }
    if (cancelled()) return (text: text, failures: 0);
    try {
      final request = proofreader.proofread(text);
      _inFlight[proofreader] = request.then<void>(
        (_) {},
        onError: (Object _) {},
      );
      run.requests++;
      final watch = Stopwatch()..start();
      final String suggestion;
      try {
        suggestion = (await request.timeout(timeout)).trim();
      } finally {
        run.inferenceMs += watch.elapsedMilliseconds;
      }
      if (suggestion.isEmpty || !_sameEmoji(text, suggestion)) {
        return (text: text, failures: 1);
      }
      return (text: suggestion, failures: 0);
    } on ProofreadException catch (error) {
      if (error.tooSmall) return (text: text, failures: 0);
      // The model enforces its own token limit; halve only on that error.
      final halves = error.tooLarge && depth < maxSplitDepth
          ? _halve(text)
          : null;
      if (halves == null) return (text: text, failures: 1);
      final left = await _attempt(run, halves.left, depth + 1);
      final right = await _attempt(run, halves.right, depth + 1);
      return (
        text: '${left.text}${halves.gap}${right.text}',
        failures: left.failures + right.failures,
      );
    } on TimeoutException {
      run.stalled = true;
      return (text: text, failures: 1);
    } catch (_) {
      return (text: text, failures: 1);
    }
  }
}

bool _sameEmoji(String before, String after) {
  final a = _emoji.allMatches(before).map((match) => match.group(0)).toList();
  final b = _emoji.allMatches(after).map((match) => match.group(0)).toList();
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Splits at the whitespace closest to the middle, or the middle character.
({String left, String gap, String right})? _halve(String text) {
  final chars = text.characters.toList();
  if (chars.length < 2) return null;
  final middle = chars.length ~/ 2;
  int? best;
  for (var i = 1; i < chars.length - 1; i++) {
    if (chars[i].trim().isEmpty &&
        (best == null || (i - middle).abs() < (best - middle).abs())) {
      best = i;
    }
  }
  if (best == null) {
    return (
      left: chars.sublist(0, middle).join(),
      gap: '',
      right: chars.sublist(middle).join(),
    );
  }
  var start = best;
  while (start > 0 && chars[start - 1].trim().isEmpty) {
    start--;
  }
  var end = best;
  while (end < chars.length && chars[end].trim().isEmpty) {
    end++;
  }
  return (
    left: chars.sublist(0, start).join(),
    gap: chars.sublist(start, end).join(),
    right: chars.sublist(end).join(),
  );
}

class _Hunk {
  _Hunk(this.oStart, this.oEnd, this.sStart, this.sEnd);

  // UTF-16 range in the original and in the suggestion.
  int oStart;
  int oEnd;
  int sStart;
  int sEnd;
}

bool _space(String text, int index) => text[index].trim().isEmpty;

/// Turns a whole-piece suggestion into word-level suggestions so each change
/// can be applied on its own. Offsets are shifted by [offset] into the
/// checked text.
List<CorrectionSuggestion> wordSuggestions(
  String original,
  String suggestion,
  int offset,
) {
  final raw = <_Hunk>[];
  var i = 0;
  var j = 0;
  _Hunk? open;
  for (final span in diffText(original, suggestion)) {
    final length = span.text.length;
    switch (span.kind) {
      case DiffKind.same:
        if (open != null) raw.add(open);
        open = null;
        i += length;
        j += length;
      case DiffKind.removed:
        open ??= _Hunk(i, i, j, j);
        i += length;
        open.oEnd = i;
      case DiffKind.added:
        open ??= _Hunk(i, i, j, j);
        j += length;
        open.sEnd = j;
    }
  }
  if (open != null) raw.add(open);

  // Text outside the hunks is identical on both sides, so growing a hunk over
  // it moves both ranges by the same amount.
  final hunks = <_Hunk>[];
  for (var k = 0; k < raw.length; k++) {
    var hunk = raw[k];
    final floor = hunks.isEmpty ? 0 : hunks.last.oEnd;
    while (hunk.oStart > floor &&
        !_space(original, hunk.oStart - 1) &&
        (hunk.oStart == hunk.oEnd || !_space(original, hunk.oStart))) {
      hunk
        ..oStart -= 1
        ..sStart -= 1;
    }
    if (hunks.isNotEmpty && hunk.oStart == floor) {
      hunk = hunks.removeLast()
        ..oEnd = hunk.oEnd
        ..sEnd = hunk.sEnd;
    }
    while (true) {
      final ceiling = k + 1 < raw.length ? raw[k + 1].oStart : original.length;
      while (hunk.oEnd < ceiling &&
          !_space(original, hunk.oEnd) &&
          (hunk.oStart == hunk.oEnd || !_space(original, hunk.oEnd - 1))) {
        hunk
          ..oEnd += 1
          ..sEnd += 1;
      }
      if (k + 1 < raw.length && hunk.oEnd == raw[k + 1].oStart) {
        final next = raw[++k];
        hunk
          ..oEnd = next.oEnd
          ..sEnd = next.sEnd;
        continue;
      }
      break;
    }
    hunks.add(hunk);
  }

  return [
    for (final hunk in hunks)
      CorrectionSuggestion(
        start: offset + hunk.oStart,
        end: offset + hunk.oEnd,
        replacement: suggestion.substring(hunk.sStart, hunk.sEnd),
        reason: _reason(
          original.substring(hunk.oStart, hunk.oEnd),
          suggestion.substring(hunk.sStart, hunk.sEnd),
        ),
      ),
  ];
}

final _whitespace = RegExp(r'\s');

String _reason(String before, String after) {
  if (after.isEmpty) return '삭제 제안';
  if (before.replaceAll(_whitespace, '') == after.replaceAll(_whitespace, '')) {
    return '띄어쓰기';
  }
  return '맞춤법·표현';
}

enum DiffKind { same, removed, added }

typedef DiffSpan = ({DiffKind kind, String text});

/// Character-level difference used to locate and highlight changes.
List<DiffSpan> diffText(String before, String after) {
  final a = before.characters.toList();
  final b = after.characters.toList();
  if (a.length * b.length > 250000) {
    return [
      (kind: DiffKind.removed, text: before),
      (kind: DiffKind.added, text: after),
    ];
  }
  final common = List.generate(
    a.length + 1,
    (_) => List.filled(b.length + 1, 0),
  );
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      common[i][j] = a[i] == b[j]
          ? common[i + 1][j + 1] + 1
          : max(common[i + 1][j], common[i][j + 1]);
    }
  }
  final spans = <DiffSpan>[];
  void push(DiffKind kind, String text) {
    if (spans.isNotEmpty && spans.last.kind == kind) {
      spans.last = (kind: kind, text: spans.last.text + text);
    } else {
      spans.add((kind: kind, text: text));
    }
  }

  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      push(DiffKind.same, a[i]);
      i++;
      j++;
    } else if (common[i + 1][j] >= common[i][j + 1]) {
      push(DiffKind.removed, a[i++]);
    } else {
      push(DiffKind.added, b[j++]);
    }
  }
  while (i < a.length) {
    push(DiffKind.removed, a[i++]);
  }
  while (j < b.length) {
    push(DiffKind.added, b[j++]);
  }
  return spans;
}
