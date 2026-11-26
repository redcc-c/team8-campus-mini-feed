import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/community_repository.dart';
import '../data/demo_repository.dart';
import '../data/firebase_repository.dart';
import '../features/ai/correction_service.dart';
import '../features/ai/on_device_correction_service.dart';

const emulatorProjectId = 'demo-team8-campus';

class AppServices {
  const AppServices({
    required this.repository,
    required this.correction,
    required this.isDemo,
    this.isCloud = false,
  });
  final CommunityRepository repository;
  final CorrectionService correction;
  final bool isDemo;
  final bool isCloud;
}

Future<AppServices> bootstrap() async {
  const useCloud = bool.fromEnvironment('USE_FIREBASE_CLOUD');
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (useCloud && useEmulators) {
    throw StateError('Select only one Firebase mode.');
  }
  if (useCloud) return _bootstrapCloud();
  if (!useEmulators) {
    return AppServices(
      repository: DemoCommunityRepository(),
      correction: await OnDeviceCorrectionService.create(),
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
    correction: await OnDeviceCorrectionService.create(),
    isDemo: false,
  );
}

Future<AppServices> _bootstrapCloud() async {
  const options = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  );
  if (options.apiKey.trim().isEmpty ||
      options.appId.trim().isEmpty ||
      options.messagingSenderId.trim().isEmpty ||
      options.projectId.trim().isEmpty ||
      options.projectId.startsWith('demo-')) {
    throw StateError('Missing or invalid cloud Firebase configuration.');
  }

  final app = Firebase.apps.any((app) => app.name == '[DEFAULT]')
      ? Firebase.app()
      : await Firebase.initializeApp(options: options);
  if (app.options.projectId != options.projectId ||
      app.options.appId != options.appId) {
    throw StateError(
      'The default Firebase app uses a different project or app.',
    );
  }
  final auth = FirebaseAuth.instanceFor(app: app);
  final user =
      auth.currentUser ??
      (await auth.signInAnonymously().timeout(const Duration(seconds: 15)))
          .user;
  if (user == null || !user.isAnonymous) {
    throw StateError('An anonymous Firebase session is required.');
  }

  return AppServices(
    repository: FirebaseCommunityRepository(
      firestore: FirebaseFirestore.instanceFor(app: app),
      userId: user.uid,
    ),
    correction: const UnavailableCorrectionService(),
    isDemo: false,
    isCloud: true,
  );
}
