import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/validation.dart';
import '../../data/community_repository.dart';
import '../../widgets/campus_style.dart';

Future<bool> openPostReport(
  BuildContext context,
  CommunityRepository repository,
  String postId,
) async {
  final open = await showCampusSheet<bool>(
    context,
    (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => Navigator.of(sheetContext).pop(true),
          child: const SizedBox(
            height: 48,
            child: Row(
              spacing: 12,
              children: [
                CampusIcon('flag', size: 24),
                Text(
                  '신고하기',
                  style: TextStyle(color: CampusColors.secondaryInk),
                ),
              ],
            ),
          ),
        ),
        const Divider(color: CampusColors.border),
        TextButton(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('취소'),
        ),
      ],
    ),
  );
  if (open != true || !context.mounted) return false;
  return await showCampusSheet<bool>(
        context,
        (_) => _ReportSheet(repository: repository, postId: postId),
      ) ??
      false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.repository, required this.postId});

  final CommunityRepository repository;
  final String postId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  bool _failed = false;
  bool _done = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    final details = _details.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await widget.repository
          .reportPost(
            postId: widget.postId,
            reason: reason,
            details: reason == ReportReason.other && details.isNotEmpty
                ? details
                : null,
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: _done
          ? [
              const Align(
                alignment: Alignment.centerLeft,
                child: CampusIcon('report-success', size: 48),
              ),
              const Text('신고가 접수됐어요', style: _titleStyle),
              const Text(
                '알려 주셔서 고마워요. 신고 내용을 확인할게요.',
                style: _descriptionStyle,
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('확인'),
              ),
            ]
          : [
              const Text('이 글을 신고할까요?', style: _titleStyle),
              const Text('운영팀이 확인하고 필요한 조치를 해요.', style: _descriptionStyle),
              Column(
                children: [
                  for (final reason in ReportReason.values) _reasonRow(reason),
                ],
              ),
              if (_reason == null)
                const Text('신고 이유를 선택해 주세요', style: _metaStyle),
              if (_reason == ReportReason.other) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '자세한 내용은 선택이에요',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${_details.text.runes.length} / $maxCommentLength',
                      style: _metaStyle,
                    ),
                  ],
                ),
                TextField(
                  controller: _details,
                  enabled: !_sending,
                  minLines: 2,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '자세한 내용을 적어 주세요(선택)',
                  ),
                ),
              ],
              FilledButton(
                onPressed:
                    _reason == null ||
                        _sending ||
                        (_reason == ReportReason.other &&
                            _details.text.runes.length > maxCommentLength)
                    ? null
                    : _send,
                child: Text(_sending ? '신고 중…' : '신고하기'),
              ),
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              if (_failed)
                const Text(
                  '접수하지 못했어요. 잠시 후 다시 시도해 주세요.',
                  style: TextStyle(color: CampusColors.error),
                ),
            ],
    ),
  );

  Widget _reasonRow(ReportReason reason) {
    final selected = _reason == reason;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? CampusColors.primarySoft : CampusColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _sending ? null : () => setState(() => _reason = reason),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                spacing: 12,
                children: [
                  CampusIcon(selected ? 'radio-on' : 'radio-off'),
                  Expanded(
                    child: Text(
                      reason.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
const _descriptionStyle = TextStyle(
  fontSize: 15,
  color: CampusColors.secondaryInk,
);
const _metaStyle = TextStyle(fontSize: 12, color: CampusColors.secondaryInk);
