import 'package:flutter/material.dart';

import '../../widgets/campus_style.dart';
import 'correction_service.dart';

Future<String?> showCorrectionSheet(
  BuildContext context,
  CorrectionService service,
  String original,
) => showCampusSheet<String>(
  context,
  (_) => _CorrectionSheet(service: service, original: original),
);

class _CorrectionSheet extends StatefulWidget {
  const _CorrectionSheet({required this.service, required this.original});

  final CorrectionService service;
  final String original;

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  late final _candidate = _check();

  Future<String> _check() async {
    final result = await widget.service
        .check(widget.original)
        .timeout(const Duration(seconds: 30));
    if (result.originalText != widget.original) {
      throw StateError('교정 요청과 원문이 일치하지 않아요.');
    }
    var corrected = result.originalText;
    var previousStart = corrected.length;
    final changes = result.suggestions.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    for (final change in changes) {
      if (change.start < 0 ||
          change.end < change.start ||
          change.end > previousStart) {
        throw StateError('수정 범위가 겹치거나 올바르지 않아요.');
      }
      corrected = corrected.replaceRange(
        change.start,
        change.end,
        change.replacement,
      );
      previousStart = change.start;
    }
    return corrected;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _candidate,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return _content('문장을 확인하고 있어요', '기기에서 맞춤법과 띄어쓰기를 확인하고 있어요.');
      }
      if (snapshot.hasError) {
        return _content('교정을 완료하지 못했어요', '원문은 그대로예요. 계속 작성할 수 있어요.', [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('계속 작성하기'),
          ),
        ]);
      }
      final candidate = snapshot.requireData;
      if (candidate == widget.original) {
        return _content('수정 제안이 없어요', '작성한 문장은 그대로 유지돼요.', [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ]);
      }
      return _content('이렇게 바꿔 볼까요?', '바뀐 부분을 확인하고 적용할지 선택해 주세요.', [
        _example('원문', widget.original),
        _example('수정 후보', candidate),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(candidate),
          child: const Text('수정 후보 적용'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('원문 유지'),
        ),
      ]);
    },
  );

  Widget _content(
    String title,
    String message, [
    List<Widget> actions = const [],
  ]) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      Text(
        message,
        style: const TextStyle(fontSize: 14, color: CampusColors.secondaryInk),
      ),
      ...actions,
    ],
  );

  Widget _example(String label, String value) => DecoratedBox(
    decoration: BoxDecoration(
      color: CampusColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: CampusColors.secondaryInk,
            ),
          ),
        ],
      ),
    ),
  );
}
