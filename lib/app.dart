import 'package:flutter/material.dart';

import 'core/bootstrap.dart';
import 'features/boards/board_screen.dart';
import 'features/feed/feed_screen.dart';
import 'widgets/campus_style.dart';

final _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: CampusColors.borderStrong, width: 1.5),
);

final campusTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: CampusColors.primary).copyWith(
    primary: CampusColors.primary,
    onPrimary: Colors.white,
    surface: CampusColors.surface,
    onSurface: CampusColors.ink,
  ),
  scaffoldBackgroundColor: CampusColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: CampusColors.background,
    foregroundColor: CampusColors.ink,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: CampusColors.ink,
      fontSize: 22,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      backgroundColor: CampusColors.surface,
      foregroundColor: CampusColors.ink,
      side: const BorderSide(color: CampusColors.borderStrong, width: 1.5),
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
    home: services.isDemo
        ? FeedScreen(services: services)
        : BoardScreen(services: services),
  );
}
