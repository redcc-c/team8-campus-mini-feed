import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class CampusColors {
  static const background = Color(0xFFF6F8F7);
  static const surface = Colors.white;
  static const muted = Color(0xFFEEF1EF);
  static const border = Color(0xFFDBE2DE);
  static const borderStrong = Color(0xFF8A938E);
  static const ink = Color(0xFF1B1F1D);
  static const secondaryInk = Color(0xFF55605A);
  static const tertiaryInk = Color(0xFF65706A);
  static const disabledInk = Color(0xFF9AA39E);
  static const error = Color(0xFFB7372C);
  static const errorSoft = Color(0xFFFCE9E5);
  static const primary = Color(0xFF0E8068);
  static const primarySoft = Color(0xFFE3F4EE);
  static const onPrimarySoft = Color(0xFF0B6B57);
}

class CampusIcon extends StatelessWidget {
  const CampusIcon(this.name, {this.size = 20, this.color, super.key});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

class CampusBackButton extends StatelessWidget {
  const CampusBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    padding: const EdgeInsets.only(left: 16),
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    icon: const CampusIcon('back'),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}

class CampusBookmarkButton extends StatelessWidget {
  const CampusBookmarkButton({
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: selected ? '북마크 해제' : '북마크 저장',
    onPressed: onPressed,
    icon: CampusIcon(selected ? 'bookmark-selected' : 'bookmark'),
  );
}

class CampusChoice extends StatelessWidget {
  const CampusChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? CampusColors.primarySoft : CampusColors.surface,
            border: Border.all(
              color: selected
                  ? CampusColors.primary
                  : CampusColors.borderStrong,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              if (selected) const CampusIcon('check', size: 24),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? CampusColors.onPrimarySoft
                        : CampusColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CampusStatus extends StatelessWidget {
  const CampusStatus({
    required this.title,
    required this.message,
    this.icon,
    this.iconSize = 48,
    this.actionLabel,
    this.onAction,
    this.actionWidth,
    super.key,
  });

  final String title;
  final String message;
  final String? icon;
  final double iconSize;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double? actionWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (icon case final name?) CampusIcon(name, size: iconSize),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: CampusColors.secondaryInk,
            ),
          ),
          if (actionLabel case final label?)
            Align(
              child: SizedBox(
                width: actionWidth ?? double.infinity,
                child: FilledButton(onPressed: onAction, child: Text(label)),
              ),
            ),
        ],
      ),
    ),
  );
}

Future<T?> showCampusSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: CampusColors.surface,
      barrierColor: const Color(0x730E1924),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: builder(context),
          ),
        ),
      ),
    );
