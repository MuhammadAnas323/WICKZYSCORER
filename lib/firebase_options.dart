// File generated for Development.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Development Firebase apps.
class DefaultFirebaseOptionsDev {
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
        throw UnsupportedError(
          'DefaultFirebaseOptionsDev have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptionsDev have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptionsDev are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCppOBZbqId6yV3D3Fyt_5ZW5oT0jibvTU',
    appId: '1:217796585547:web:REPLACE_ME',
    messagingSenderId: '217796585547',
    projectId: 'fitnessapp-bcc3b',
    authDomain: 'fitnessapp-bcc3b.firebaseapp.com',
    storageBucket: 'fitnessapp-bcc3b.appspot.com',
    measurementId: 'G-REPLACE_ME',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwfhk3MSCFk6kHJ9-3Tfc9OtnbeM_028U',
    appId: '1:217796585547:android:9058f3eb1b448a01f485ce',
    messagingSenderId: '217796585547',
    projectId: 'fitnessapp-bcc3b',
    storageBucket: 'fitnessapp-bcc3b.appspot.com',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBSLAnsbkOw5wL9SWgl-MpPCakCFM1r7pE',
    appId: '1:217796585547:ios:813c07130e23d0f9f485ce',
    messagingSenderId: '217796585547',
    projectId: 'fitnessapp-bcc3b',
    storageBucket: 'fitnessapp-bcc3b.firebasestorage.app',
    iosBundleId: 'com.sportyapp.sportyapp',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME_MACOS_API_KEY',
    appId: '1:217796585547:ios:REPLACE_ME',
    messagingSenderId: '217796585547',
    projectId: 'fitnessapp-bcc3b',
    storageBucket: 'fitnessapp-bcc3b.appspot.com',
    iosBundleId: 'com.example.sportyapp',
  );
}
