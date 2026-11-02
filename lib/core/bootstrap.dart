import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/community_repository.dart';
import '../data/demo_repository.dart';
import '../data/firebase_repository.dart';
import '../features/ai/correction_service.dart';

const emulatorProjectId = 'demo-team8-campus';

class AppServices {
  const AppServices({
    required this.repository,
    required this.correction,
    required this.isDemo,
  });
  final CommunityRepository repository;
  final CorrectionService correction;
  final bool isDemo;
}

Future<AppServices> bootstrap() async {
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (!useEmulators) {
    return AppServices(
      repository: DemoCommunityRepository(),
      correction: const UnavailableCorrectionService(),
      isDemo: true,
    );
  }
  const explicitHost = String.fromEnvironment('EMULATOR_HOST');
  final host = explicitHost.isNotEmpty
      ? explicitHost
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  // Firestore's platform delegate currently requires a default app even when
  // instanceFor is used. Explicitly name the demo default instead of creating
  // only a secondary app.
  final app = Firebase.apps.any((app) => app.name == '[DEFAULT]')
      ? Firebase.app()
      : await Firebase.initializeApp(
          name: '[DEFAULT]',
          demoProjectId: emulatorProjectId,
        );
  if (app.options.projectId != emulatorProjectId) {
    throw StateError('Emulator mode requires the demo project.');
  }
  final auth = FirebaseAuth.instanceFor(app: app);
  final db = FirebaseFirestore.instanceFor(app: app);
  // Explicit emulators only; no real Firebase project is selected automatically.
  await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
  db.settings = const Settings(persistenceEnabled: false);
  db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
  final credential = await auth.signInAnonymously().timeout(
    const Duration(seconds: 15),
  );
  return AppServices(
    repository: FirebaseCommunityRepository(
      firestore: db,
      userId: credential.user!.uid,
    ),
    correction: const UnavailableCorrectionService(),
    isDemo: false,
  );
}
