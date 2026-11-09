import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase options read from compile-time environment variables.
///
/// Values come from `env/dev.json` / `env/prod.json` passed with
/// `--dart-define-from-file`, so no API key is ever committed to Git.
abstract final class FirebaseEnvOptions {
  static const _apiKeyAndroid = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _appIdAndroid = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _apiKeyIos = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _appIdIos = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const FirebaseOptions(
        apiKey: _apiKeyIos,
        appId: _appIdIos,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        iosBundleId: _iosBundleId,
      );
    }
    return const FirebaseOptions(
      apiKey: _apiKeyAndroid,
      appId: _appIdAndroid,
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _storageBucket,
    );
  }
}
