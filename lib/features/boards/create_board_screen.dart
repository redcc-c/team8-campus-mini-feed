import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/validation.dart';
import '../../data/demo_repository.dart';
import '../../widgets/campus_style.dart';

class CreateBoardScreen extends StatefulWidget {
  const CreateBoardScreen({required this.repository, super.key});

  final DemoCommunityRepository repository;

  @override
  State<CreateBoardScreen> createState() => _CreateBoardScreenState();
}

class _CreateBoardScreenState extends State<CreateBoardScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _create() {
    if (!_form.currentState!.validate()) return;
    try {
      final board = widget.repository.createBoard(
        name: _name.text,
        category: _category!,
        description: _description.text,
      );
      Navigator.of(context).pop<Board>(board);
    } on StateError catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('게시판 만들기'),
      leading: const CampusBackButton(),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('게시판 이름', '${_name.text.runes.length} / 20'),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '게시판 이름을 입력해 주세요'),
            validator: (value) => validateContent(value ?? '', maxLength: 20),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          _label('카테고리'),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _category,
            icon: const CampusIcon('chevron-down'),
            decoration: const InputDecoration(hintText: '카테고리를 선택해 주세요'),
            items: [
              for (final label in ['캠퍼스 일상', '공부와 진로', '개발', '동아리', '기타'])
                DropdownMenuItem(value: label, child: Text(label)),
            ],
            onChanged: (value) => _category = value,
            validator: (value) => value == null ? '카테고리를 선택해 주세요.' : null,
          ),
          const SizedBox(height: 8),
          _label('소개', '${_description.text.runes.length} / 100'),
          TextFormField(
            controller: _description,
            minLines: 6,
            maxLines: 8,
            decoration: const InputDecoration(hintText: '게시판을 소개해 주세요'),
            validator: (value) => validateContent(value ?? '', maxLength: 100),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            '개설자  ${anonymousName(widget.repository.userId)}',
            style: const TextStyle(
              fontSize: 13,
              color: CampusColors.secondaryInk,
            ),
          ),
          if (_error case final message?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: const TextStyle(color: CampusColors.error),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: ColoredBox(
      color: CampusColors.surface,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton(onPressed: _create, child: const Text('게시판 만들기')),
      ),
    ),
  );

  Widget _label(String label, [String? count]) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        if (count != null)
          Text(
            count,
            style: const TextStyle(
              fontSize: 12,
              color: CampusColors.tertiaryInk,
            ),
          ),
      ],
    ),
  );
}
