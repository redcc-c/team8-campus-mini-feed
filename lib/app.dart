import 'package:flutter/material.dart';

import 'core/bootstrap.dart';
import 'features/boards/board_screen.dart';

final campusTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF285B4B)),
  scaffoldBackgroundColor: const Color(0xFFF7F8F5),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF7F8F5),
    centerTitle: false,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
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
    home: BoardScreen(services: services),
  );
}
