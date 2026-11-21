import 'package:flutter/material.dart';

import '../../widgets/campus_style.dart';
import 'correction_engine.dart';
import 'correction_service.dart';

Future<String?> showCorrectionSheet(
  BuildContext context,
  CorrectionService service,
  String original,
) => showCampusSheet<String>(
  context,
  (_) => _CorrectionRequest(service: service, original: original),
);

Future<List<CorrectionSuggestion>?> showCorrectionSuggestions(
  BuildContext context,
  CorrectionResult result,
) => showCampusSheet<List<CorrectionSuggestion>>(
  context,
  (_) => _CorrectionSheet(result: result),
);

class _CorrectionRequest extends StatefulWidget {
  const _CorrectionRequest({required this.service, required this.original});
  final CorrectionService service;
  final String original;

  @override
  State<_CorrectionRequest> createState() => _CorrectionRequestState();
}

class _CorrectionRequestState extends State<_CorrectionRequest> {
  late final _result = _check();

  Future<CorrectionResult> _check() async {
    final result = await widget.service.check(
      widget.original,
      isCancelled: () => !mounted,
    );
    if (result.originalText != widget.original || result.allFailed) {
      throw StateError('교정을 완료하지 못했습니다.');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CorrectionResult>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return _CorrectionSheet(result: snapshot.requireData, returnText: true);
      }
      final failed = snapshot.hasError;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(failed ? '교정을 완료하지 못했어요' : '문장을 확인하고 있어요'),
          Text(
            failed
                ? '원문은 그대로예요. 계속 작성할 수 있어요.'
                : '처음에는 모델을 내려받느라 몇 분 걸릴 수 있습니다.',
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(failed ? '계속 작성하기' : '중지'),
          ),
        ],
      );
    },
  );
}

class _CorrectionSheet extends StatefulWidget {
  const _CorrectionSheet({required this.result, this.returnText = false});

  final CorrectionResult result;
  final bool returnText;

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  late final _items = widget.result.suggestions;
  late final Set<CorrectionSuggestion> _selected = {..._items};

  void _toggle(CorrectionSuggestion item) => setState(() {
    if (!_selected.remove(item)) _selected.add(item);
  });

  void _apply() {
    final selected = [
      for (final item in _items)
        if (_selected.contains(item)) item,
    ];
    if (widget.returnText) {
      Navigator.of(context).pop(widget.result.applyAll(selected));
    } else {
      Navigator.of(context).pop(selected);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Text(
        _items.isEmpty ? '고칠 부분을 찾지 못했습니다.' : '교정 제안 ${_items.length}개',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      Text(
        _items.isEmpty
            ? '검사를 마친 부분에서는 고칠 곳이 없었습니다.'
            : '적용할 제안을 골라 주세요. 적용한 뒤에도 원문으로 되돌릴 수 있습니다.',
        style: const TextStyle(fontSize: 14, color: CampusColors.secondaryInk),
      ),
      if (widget.result.failedSegments > 0)
        const Text('교정하지 못한 부분은 원문으로 유지했습니다.'),
      if (_items.length > 1)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('ai-select-all'),
            onPressed: () => setState(() {
              _selected.length == _items.length
                  ? _selected.clear()
                  : _selected.addAll(_items);
            }),
            child: Text(_selected.length == _items.length ? '모두 해제' : '모두 선택'),
          ),
        ),
      for (final item in _items) _suggestion(item),
      if (_items.isEmpty)
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        )
      else ...[
        FilledButton(
          key: const ValueKey('ai-apply'),
          onPressed: _selected.isEmpty ? null : _apply,
          child: Text('${_selected.length}개 적용'),
        ),
        TextButton(
          key: const ValueKey('ai-keep-original'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('원문 유지'),
        ),
      ],
    ],
  );

  Widget _suggestion(CorrectionSuggestion item) => DecoratedBox(
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
          Row(
            children: [
              Checkbox(
                value: _selected.contains(item),
                semanticLabel: '${item.reason} 제안 적용',
                onChanged: (_) => _toggle(item),
              ),
              Expanded(
                child: Text(
                  item.reason,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          _diffLine('원문', item, DiffKind.removed),
          _diffLine('제안', item, DiffKind.added),
        ],
      ),
    ),
  );

  Widget _diffLine(
    String label,
    CorrectionSuggestion item,
    DiffKind highlight,
  ) {
    final spans = diffText(
      widget.result.originalText.substring(item.start, item.end),
      item.replacement,
    );
    final colors = Theme.of(context).colorScheme;
    final marked = highlight == DiffKind.removed
        ? TextStyle(
            color: colors.onErrorContainer,
            backgroundColor: colors.errorContainer,
            decoration: TextDecoration.lineThrough,
          )
        : TextStyle(
            color: colors.onPrimaryContainer,
            backgroundColor: colors.primaryContainer,
            fontWeight: FontWeight.w700,
          );
    final shown = spans.where(
      (span) => span.kind == DiffKind.same || span.kind == highlight,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label  '),
          if (shown.isEmpty)
            TextSpan(
              text: highlight == DiffKind.added ? '(삭제)' : '(없음)',
              style: marked,
            )
          else
            for (final span in shown)
              TextSpan(
                text: span.text,
                style: span.kind == DiffKind.same ? null : marked,
              ),
        ],
      ),
    );
  }
}
