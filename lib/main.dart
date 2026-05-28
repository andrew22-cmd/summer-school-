import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/class_member_provider.dart';
import 'package:summerschool/providers/attendance_provider.dart';
import 'package:summerschool/providers/points_provider.dart';
import 'package:summerschool/providers/attachment_provider.dart';
import 'package:summerschool/providers/follow_up_provider.dart';
import 'package:summerschool/providers/task_provider.dart';
import 'package:summerschool/services/fcm_service.dart';
import 'package:summerschool/services/attachment_service.dart';
import 'package:summerschool/services/follow_up_service.dart';
import 'package:summerschool/services/task_service.dart';
import 'core/app.dart';
import 'firebase_options.dart';
import 'services/class_member_service.dart';
import 'services/attendance_service.dart';
import 'providers/auth_provider.dart';
import 'services/firestore_user_service.dart';
import 'services/local_storage_service.dart';
import 'services/points_service.dart';
// (done)weekly schd. will be sunday and wednsday
// (done)for manager can see history of points
//(done)manager can in attachments send for member-manager or managers only not members or all
// reminder for event before one day from event
//(done)task history and can be edit - now inside add task tab
// (done)delete student from class (remove it)
//(done) in add points must select reason and points counted on this reason
// (done)when any operation made on points must make it in table due to  overflow of data
// where I need to make it pdf good for printing
// gembeooyny -->imp
//(done) in visits member can visit total 2 in month and date that he visit in can manager and mebermanager see it
// (done)attendance of members

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();

  final fcmService = FcmService();
  await fcmService.initialize();

  final localStorage = LocalStorageService();
  await _runSilentStageNormMigration(localStorage);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStorageService>(create: (_) => localStorage),
        Provider<FirestoreUserService>(create: (_) => FirestoreUserService()),
        Provider<FcmService>.value(value: fcmService),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            firestoreUserService: context.read<FirestoreUserService>(),
            fcmService: context.read<FcmService>(),
          )..initialize(),
        ),
        ChangeNotifierProvider<ClassMemberProvider>(
          create: (_) => ClassMemberProvider(service: ClassMemberService()),
        ),
        ChangeNotifierProvider<AttendanceProvider>(
          create: (_) => AttendanceProvider(service: AttendanceService()),
        ),
        ChangeNotifierProvider<PointsProvider>(
          create: (_) => PointsProvider(PointsService()),
        ),
        ChangeNotifierProvider<FollowUpProvider>(
          create: (_) => FollowUpProvider(service: FollowUpService()),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (context) => TaskProvider(
            service: TaskService(
              firestoreUserService: context.read<FirestoreUserService>(),
            ),
          ),
        ),
        ChangeNotifierProvider<AttachmentProvider>(
          create: (_) => AttachmentProvider(AttachmentService()),
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
