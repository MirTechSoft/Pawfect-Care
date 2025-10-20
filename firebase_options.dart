
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDq9LtDA2pAFuqrZPHW76Kb8x7r9OvYECE',
    appId: '1:919666388073:web:ec0d824e1d2be7b39446f8',
    messagingSenderId: '919666388073',
    projectId: 'pet-app-cb56e',
    authDomain: 'pet-app-cb56e.firebaseapp.com',
    storageBucket: 'pet-app-cb56e.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAw-i44pczc4UoqJvOVvoJG104VZBewYG8',
    appId: '1:919666388073:android:6c9f5f9b730e3b719446f8',
    messagingSenderId: '919666388073',
    projectId: 'pet-app-cb56e',
    storageBucket: 'pet-app-cb56e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAp_AHDgDlNFlJdXuT2G66BK8qvlSnD654',
    appId: '1:919666388073:ios:45220eb3cd3b7ea89446f8',
    messagingSenderId: '919666388073',
    projectId: 'pet-app-cb56e',
    storageBucket: 'pet-app-cb56e.firebasestorage.app',
    iosBundleId: 'com.example.petApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAp_AHDgDlNFlJdXuT2G66BK8qvlSnD654',
    appId: '1:919666388073:ios:45220eb3cd3b7ea89446f8',
    messagingSenderId: '919666388073',
    projectId: 'pet-app-cb56e',
    storageBucket: 'pet-app-cb56e.firebasestorage.app',
    iosBundleId: 'com.example.petApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDq9LtDA2pAFuqrZPHW76Kb8x7r9OvYECE',
    appId: '1:919666388073:web:0967101da5b438399446f8',
    messagingSenderId: '919666388073',
    projectId: 'pet-app-cb56e',
    authDomain: 'pet-app-cb56e.firebaseapp.com',
    storageBucket: 'pet-app-cb56e.firebasestorage.app',
  );
}
