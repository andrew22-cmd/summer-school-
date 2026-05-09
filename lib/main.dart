import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/firestore_user_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStorageService>(create: (_) => LocalStorageService()),
        Provider<FirestoreUserService>(create: (_) => FirestoreUserService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            firestoreUserService: context.read<FirestoreUserService>(),
          )..initialize(),
        ),
      ],
      child: const SummerSchoolApp(),
    ),
  );
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
