import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Replace these values with your actual Firebase Project config from console.firebase.google.com
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  // Web Firebase configuration for UNO No Mercy
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyUnoNoMercy1234567890',
    appId: '1:1020651641252:web:demoappuno',
    messagingSenderId: '1020651641252',
    projectId: 'uno-no-mercy-live',
    authDomain: 'uno-no-mercy-live.firebaseapp.com',
    storageBucket: 'uno-no-mercy-live.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyUnoNoMercy1234567890',
    appId: '1:1020651641252:android:demoappuno',
    messagingSenderId: '1020651641252',
    projectId: 'uno-no-mercy-live',
    storageBucket: 'uno-no-mercy-live.appspot.com',
  );
}
