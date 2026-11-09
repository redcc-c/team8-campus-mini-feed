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
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    icon: const CampusIcon('back'),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}
