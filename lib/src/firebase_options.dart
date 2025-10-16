import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Replace with values from your Firebase project (flutterfire configure preferred)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: dotenv.env['APIKEY'] ?? '',
        authDomain: dotenv.env['AUTHDOMAIN'],
        projectId: dotenv.env['PROJECTID'] ?? '',
        storageBucket: dotenv.env['STORAGEBUCKET'],
        messagingSenderId: dotenv.env['MESSAGINGSENDERID'] ?? '',
        appId: dotenv.env['APPID'] ?? '',
        measurementId: dotenv.env['MEASUREMENTID'],
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: dotenv.env['IOS_API_KEY'] ?? '',
          appId: dotenv.env['IOS_APP_ID'] ?? '',
          messagingSenderId: dotenv.env['IOS_SENDER_ID'] ?? '',
          projectId: dotenv.env['IOS_PROJECT_ID'] ?? '',
          storageBucket: dotenv.env['IOS_STORAGE_BUCKET'],
          iosBundleId: dotenv.env['IOS_BUNDLE_ID'],
        );
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: dotenv.env['ANDROID_API_KEY'] ?? '',
          appId: dotenv.env['ANDROID_APP_ID'] ?? '',
          messagingSenderId: dotenv.env['ANDROID_SENDER_ID'] ?? '',
          projectId: dotenv.env['ANDROID_PROJECT_ID'] ?? '',
          storageBucket: dotenv.env['ANDROID_STORAGE_BUCKET'],
        );
      default:
        return FirebaseOptions(
          apiKey: dotenv.env['APIKEY'] ?? '',
          appId: dotenv.env['APPID'] ?? '',
          messagingSenderId: dotenv.env['MESSAGINGSENDERID'] ?? '',
          projectId: dotenv.env['PROJECTID'] ?? '',
        );
    }
  }
}
