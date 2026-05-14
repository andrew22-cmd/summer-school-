import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/class_member_provider.dart';
import 'core/app.dart';
import 'firebase_options.dart';
import 'services/class_member_service.dart';
import 'providers/auth_provider.dart';
import 'services/firestore_user_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();

  final localStorage = LocalStorageService();
  await _runSilentStageNormMigration(localStorage);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStorageService>(create: (_) => localStorage),
        Provider<FirestoreUserService>(create: (_) => FirestoreUserService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            firestoreUserService: context.read<FirestoreUserService>(),
          )..initialize(),
        ),
        ChangeNotifierProvider<ClassMemberProvider>(
          create: (_) => ClassMemberProvider(service: ClassMemberService()),
        ),
      ],
      child: const SummerSchoolApp(),
    ),
  );
}

Future<void> _runSilentStageNormMigration(
  LocalStorageService localStorage,
) async {
  try {
    final alreadyMigrated = await localStorage
        .getClassMembersStageNormMigrated();
    if (alreadyMigrated) {
      debugPrint(
        '[StartupMigration] class_members stage_norm already migrated.',
      );
      return;
    }

    debugPrint(
      '[StartupMigration] Starting silent class_members stage_norm migration...',
    );
    final service = ClassMemberService();
    final updated = await service.migrateAddStageNormAll();
    await localStorage.setClassMembersStageNormMigrated(true);
    debugPrint('[StartupMigration] Completed. Updated $updated documents.');
  } catch (error) {
    debugPrint('[StartupMigration] Failed: $error');
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }
}
