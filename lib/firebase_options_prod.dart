// File generated for Production.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Production Firebase apps.
class DefaultFirebaseOptionsProd {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptionsProd have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptionsProd have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptionsProd have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptionsProd have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptionsProd are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA8f3DMAIFVvbqWb3LDLptWW8x4hpwiNtU',
    appId: '1:508811444603:android:0bcf7da0dfa4c529fe3dde',
    messagingSenderId: '508811444603',
    projectId: 'wickzyscorer-prod-9921',
    storageBucket: 'wickzyscorer-prod-9921.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCCmAr2Dh3jH-T8dSUFsnGK2XG0Wvz-oik',
    appId: '1:508811444603:ios:534e716f502523bffe3dde',
    messagingSenderId: '508811444603',
    projectId: 'wickzyscorer-prod-9921',
    storageBucket: 'wickzyscorer-prod-9921.firebasestorage.app',
    iosBundleId: 'com.sportyapp.sportyapp',
  );
}
