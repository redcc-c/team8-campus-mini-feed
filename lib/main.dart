import 'package:flutter/material.dart';

import 'app.dart';
import 'core/bootstrap.dart';
import 'widgets/campus_style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<AppServices> _services = bootstrap();
  @override
  Widget build(BuildContext context) => FutureBuilder<AppServices>(
    future: _services,
    builder: (context, snapshot) {
      if (snapshot.hasData) return CampusApp(services: snapshot.requireData);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: campusTheme,
        home: Scaffold(
          body: SafeArea(
            child:
                snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasError
                ? CampusStatus(
                    icon: 'shield',
                    iconSize: 20,
                    title: '연결을 확인해 주세요',
                    message: '인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
                    actionLabel: '다시 시도',
                    actionWidth: 216,
                    onAction: () => setState(() => _services = bootstrap()),
                  )
                : const CampusStatus(
                    icon: 'shield',
                    iconSize: 20,
                    title: '앱을 준비하고 있어요',
                    message: '익명 세션을 연결하고 있어요.',
                  ),
          ),
        ),
      );
    },
  );
}
