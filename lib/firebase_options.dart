import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDEyC8o0fWcpM0utDvrH-eizFD-QT6jW8c',
    appId: '1:279809808505:android:332cfedc3db1aaa3df1ca8',
    messagingSenderId: '279809808505',
    projectId: 'summer-school-2f0a7',
    storageBucket: 'summer-school-2f0a7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDEyC8o0fWcpM0utDvrH-eizFD-QT6jW8c',
    appId: '1:279809808505:ios:332cfedc3db1aaa3df1ca8',
    messagingSenderId: '279809808505',
    projectId: 'summer-school-2f0a7',
    storageBucket: 'summer-school-2f0a7.firebasestorage.app',
    iosBundleId: 'com.example.summerschool',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDEyC8o0fWcpM0utDvrH-eizFD-QT6jW8c',
    appId: '1:279809808505:macos:332cfedc3db1aaa3df1ca8',
    messagingSenderId: '279809808505',
    projectId: 'summer-school-2f0a7',
    storageBucket: 'summer-school-2f0a7.firebasestorage.app',
    iosBundleId: 'com.example.summerschool',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDEyC8o0fWcpM0utDvrH-eizFD-QT6jW8c',
    appId: '1:279809808505:web:332cfedc3db1aaa3df1ca8',
    messagingSenderId: '279809808505',
    projectId: 'summer-school-2f0a7',
    authDomain: 'summer-school-2f0a7.firebaseapp.com',
    storageBucket: 'summer-school-2f0a7.firebasestorage.app',
  );
}
