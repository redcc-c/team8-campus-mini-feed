import 'package:flutter/material.dart';

import 'core/bootstrap.dart';
import 'features/feed/feed_screen.dart';
import 'widgets/campus_style.dart';

final _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: CampusColors.borderStrong, width: 1.5),
);

final campusTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Noto Sans KR',
  colorScheme: ColorScheme.fromSeed(seedColor: CampusColors.primary).copyWith(
    primary: CampusColors.primary,
    onPrimary: Colors.white,
    surface: CampusColors.surface,
    onSurface: CampusColors.ink,
    error: CampusColors.error,
  ),
  scaffoldBackgroundColor: CampusColors.background,
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: CampusColors.primary,
    selectionColor: Color(0x660E8068),
    selectionHandleColor: CampusColors.primary,
  ),
  // Plain ripple instead of the sparkle effect: quieter, and cheaper on low-end phones.
  splashFactory: InkRipple.splashFactory,
  dividerTheme: const DividerThemeData(
    color: CampusColors.border,
    thickness: 1,
    space: 24,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: CampusColors.ink,
    contentTextStyle: const TextStyle(
      fontFamily: 'Noto Sans KR',
      color: Colors.white,
      fontSize: 14,
      height: 20 / 14,
    ),
    insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    foregroundColor: Colors.white,
    highlightElevation: 4,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: CampusColors.primary,
    linearTrackColor: CampusColors.primarySoft,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CampusColors.background,
    foregroundColor: CampusColors.ink,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: false,
    leadingWidth: 64,
    titleSpacing: 8,
    titleTextStyle: TextStyle(
      fontFamily: 'Noto Sans KR',
      color: CampusColors.ink,
      fontSize: 22,
      height: 30 / 22,
      fontWeight: FontWeight.w700,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: CampusColors.muted,
    border: _inputBorder,
    enabledBorder: _inputBorder,
    focusedBorder: _inputBorder.copyWith(
      borderSide: const BorderSide(color: CampusColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: const TextStyle(color: CampusColors.tertiaryInk),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      disabledBackgroundColor: CampusColors.muted,
      disabledForegroundColor: CampusColors.disabledInk,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      backgroundColor: CampusColors.surface,
      foregroundColor: CampusColors.ink,
      disabledForegroundColor: CampusColors.disabledInk,
      side: const BorderSide(color: CampusColors.borderStrong, width: 1.5),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);

class CampusApp extends StatelessWidget {
  const CampusApp({required this.services, super.key});
  final AppServices services;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '캠퍼스 미니 피드',
    debugShowCheckedModeBanner: false,
    theme: campusTheme,
    // On tablets, foldables and wide windows a phone feed stretched edge to
    // edge is hard to read, so the content keeps a readable column width.
    builder: (context, child) => ColoredBox(
      color: CampusColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child,
        ),
      ),
    ),
    home: FeedScreen(services: services),
  );
}
