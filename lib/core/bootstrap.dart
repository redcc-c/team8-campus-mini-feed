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
  });
  final CommunityRepository repository;
  final CorrectionService correction;
  final bool isDemo;
}

Future<AppServices> bootstrap() async {
  const useCloud = bool.fromEnvironment('USE_FIREBASE_CLOUD');
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (useCloud && useEmulators) {
    throw StateError('Choose one Firebase connection mode.');
  }
  if (!useCloud && !useEmulators) {
    return AppServices(
      repository: DemoCommunityRepository(),
      correction: await OnDeviceCorrectionService.create(),
      isDemo: true,
    );
  }
  final app = await _initializeFirebase(useEmulators: useEmulators);
  final auth = FirebaseAuth.instanceFor(app: app);
  final db = FirebaseFirestore.instanceFor(app: app);
  if (useEmulators) {
    const explicitHost = String.fromEnvironment('EMULATOR_HOST');
    final host = explicitHost.isNotEmpty
        ? explicitHost
        : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
  }
  final user =
      auth.currentUser ??
      (await auth.signInAnonymously().timeout(const Duration(seconds: 15)))
          .user;
  if (user == null || !user.isAnonymous) {
    throw StateError('An anonymous Firebase session is required.');
  }
  return AppServices(
    repository: FirebaseCommunityRepository(firestore: db, userId: user.uid),
    correction: await OnDeviceCorrectionService.create(),
    isDemo: false,
  );
}

Future<FirebaseApp> _initializeFirebase({required bool useEmulators}) async {
  const options = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  );
  if (!useEmulators &&
      [
        options.apiKey,
        options.appId,
        options.messagingSenderId,
        options.projectId,
      ].any((value) => value.trim().isEmpty)) {
    throw StateError('Missing Firebase settings in .env.');
  }
  final FirebaseApp app;
  if (Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
    app = Firebase.app();
  } else if (useEmulators) {
    app = await Firebase.initializeApp(
      name: '[DEFAULT]',
      demoProjectId: emulatorProjectId,
    );
  } else {
    app = await Firebase.initializeApp(options: options);
  }
  final projectId = useEmulators ? emulatorProjectId : options.projectId;
  if (app.options.projectId != projectId ||
      (!useEmulators && app.options.appId != options.appId)) {
    throw StateError('Firebase app does not match the selected configuration.');
  }
  return app;
}
