import 'package:flutter/material.dart';

import 'app.dart';
import 'core/bootstrap.dart';

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
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48),
                        const SizedBox(height: 16),
                        const Text('앱을 시작하지 못했습니다.'),
                        const Text('로컬 테스트 서버 연결과 실행 설정을 확인해 주세요.'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _services = bootstrap()),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}
