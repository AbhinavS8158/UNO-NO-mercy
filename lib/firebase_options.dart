import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for UNO Show 'em No Mercy
/// Connected to live Firebase project: uno-no-mercy-81afc
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

  // Live Web Firebase configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBrCT-KaYpaGr1c9FVcijXCszQ9P_LVmJM',
    authDomain: 'uno-no-mercy-81afc.firebaseapp.com',
    projectId: 'uno-no-mercy-81afc',
    storageBucket: 'uno-no-mercy-81afc.firebasestorage.app',
    messagingSenderId: '228669985780',
    appId: '1:228669985780:web:f8fe89e54ce3ad37429fa1',
    measurementId: 'G-TNBZ3TRT4F',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBrCT-KaYpaGr1c9FVcijXCszQ9P_LVmJM',
    authDomain: 'uno-no-mercy-81afc.firebaseapp.com',
    projectId: 'uno-no-mercy-81afc',
    storageBucket: 'uno-no-mercy-81afc.firebasestorage.app',
    messagingSenderId: '228669985780',
    appId: '1:228669985780:web:f8fe89e54ce3ad37429fa1',
  );
}
