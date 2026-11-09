import 'package:flutter/material.dart';

import 'correction_engine.dart';
import 'correction_service.dart';

/// Lets the author pick which suggestions to apply. Pops with the selected
/// suggestions, or `null` to keep the original.
class CorrectionSheet extends StatefulWidget {
  const CorrectionSheet({required this.result, super.key});
  final CorrectionResult result;

  @override
  State<CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<CorrectionSheet> {
  late final List<CorrectionSuggestion> _items = widget.result.suggestions;
  late final Set<CorrectionSuggestion> _selected = {..._items};

  void _toggle(CorrectionSuggestion item) => setState(() {
    if (!_selected.remove(item)) _selected.add(item);
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final failures = widget.result.failedSegments;
    final allSelected = _selected.length == _items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _items.isEmpty
                      ? '고칠 부분을 찾지 못했습니다.'
                      : '교정 제안 ${_items.length}개',
                  style: text.titleLarge,
                ),
              ),
              if (_items.length > 1)
                TextButton(
                  key: const ValueKey('ai-select-all'),
                  onPressed: () => setState(() {
                    allSelected ? _selected.clear() : _selected.addAll(_items);
                  }),
                  child: Text(allSelected ? '모두 해제' : '모두 선택'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _items.isEmpty
                ? failures > 0
                      ? '검사를 마친 부분에서는 고칠 곳이 없었습니다.'
                      : '지금 글을 그대로 사용해도 좋습니다.'
                : '적용할 제안을 골라 주세요. 적용한 뒤에도 원문으로 되돌릴 수 있습니다.',
            style: text.bodyMedium,
          ),
          if (failures > 0) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '교정하지 못한 부분은 원문으로 유지했습니다.',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _SuggestionCard(
                  original: widget.result.originalText.substring(
                    _items[index].start,
                    _items[index].end,
                  ),
                  suggestion: _items[index],
                  selected: _selected.contains(_items[index]),
                  onToggle: () => _toggle(_items[index]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_items.isEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('ai-keep-original'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('원문 유지'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('ai-apply'),
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, [
                            for (final item in _items)
                              if (_selected.contains(item)) item,
                          ]),
                    child: Text('${_selected.length}개 적용'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.original,
    required this.suggestion,
    required this.selected,
    required this.onToggle,
  });

  final String original;
  final CorrectionSuggestion suggestion;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final spans = diffText(original, suggestion.replacement);
    return Card(
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                semanticLabel: '${suggestion.reason} 제안 적용',
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.reason,
                        style: text.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DiffLine(
                        label: '원문',
                        spans: spans,
                        highlight: DiffKind.removed,
                      ),
                      const SizedBox(height: 4),
                      DiffLine(
                        label: '제안',
                        spans: spans,
                        highlight: DiffKind.added,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiffLine extends StatelessWidget {
  const DiffLine({
    required this.label,
    required this.spans,
    required this.highlight,
    super.key,
  });

  final String label;
  final List<DiffSpan> spans;

  /// [DiffKind.removed] renders the original, [DiffKind.added] the suggestion.
  final DiffKind highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final base = text.bodyLarge;
    final marked = highlight == DiffKind.removed
        ? base?.copyWith(
            color: colors.onErrorContainer,
            backgroundColor: colors.errorContainer,
            decoration: TextDecoration.lineThrough,
          )
        : base?.copyWith(
            color: colors.onPrimaryContainer,
            backgroundColor: colors.primaryContainer,
            fontWeight: FontWeight.w700,
          );
    final shown = [
      for (final span in spans)
        if (span.kind == DiffKind.same || span.kind == highlight) span,
    ];
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label  ', style: text.bodySmall),
          if (shown.isEmpty)
            TextSpan(
              text: highlight == DiffKind.added ? '(삭제)' : '(없음)',
              style: marked,
            )
          else
            for (final span in shown)
              TextSpan(
                text: span.text,
                style: span.kind == DiffKind.same ? base : marked,
              ),
        ],
      ),
    );
  }
}
