import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Replace with values from your Firebase project (flutterfire configure preferred)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'YOUR_WEB_API_KEY',
        appId: 'YOUR_WEB_APP_ID',
        messagingSenderId: 'YOUR_SENDER_ID',
        projectId: 'YOUR_PROJECT_ID',
        storageBucket: 'YOUR_STORAGE_BUCKET',
        authDomain: 'YOUR_AUTH_DOMAIN',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'IOS_API_KEY',
          appId: 'IOS_APP_ID',
          messagingSenderId: 'SENDER_ID',
          projectId: 'PROJECT_ID',
          storageBucket: 'STORAGE_BUCKET',
          iosBundleId: 'com.example.albumWebapp',
        );
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'ANDROID_API_KEY',
          appId: 'ANDROID_APP_ID',
          messagingSenderId: 'SENDER_ID',
          projectId: 'PROJECT_ID',
          storageBucket: 'STORAGE_BUCKET',
        );
      default:
        return const FirebaseOptions(
          apiKey: 'DUMMY',
          appId: 'DUMMY',
          messagingSenderId: 'DUMMY',
          projectId: 'DUMMY',
        );
    }
  }
}


