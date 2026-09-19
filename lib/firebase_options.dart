import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration for the `feedback-review-app-85786` project.
///
/// These are public project identifiers, not secrets; access is protected by
/// Firestore Security Rules. Only Android is configured so far — iOS options
/// are added once the iOS app is registered in the Firebase console.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS yet.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCvpSNroBf682kx3xL9ZhqCv6OQralUt9Y',
    appId: '1:1050801113531:android:13c6e8e71ab325881edc9e',
    messagingSenderId: '1050801113531',
    projectId: 'feedback-review-app-85786',
    storageBucket: 'feedback-review-app-85786.firebasestorage.app',
  );
}
