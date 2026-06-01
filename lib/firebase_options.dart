// 由 google-services.json / FlutterFire 生成；若你换了 Firebase 项目，请重新运行 flutterfire configure
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
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
    apiKey: 'AIzaSyB4QN4wbeAFY_i3bd8qzgBBVePVYsJGhJw',
    appId: '1:22819687623:web:df2d079baf03dd1b0ac2e2',
    messagingSenderId: '22819687623',
    projectId: 'xolv-43caf',
    authDomain: 'xolv-43caf.firebaseapp.com',
    storageBucket: 'xolv-43caf.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDMHGe0BjXYJx5EHDEFJcKo-XAxJrQFXYo',
    appId: '1:22819687623:android:87cc410820be05450ac2e2',
    messagingSenderId: '22819687623',
    projectId: 'xolv-43caf',
    storageBucket: 'xolv-43caf.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDr1AhNnLhUXPahX_XqWg8sx4jPnMrVSXk',
    appId: '1:22819687623:ios:45e5523d5d1e6bf60ac2e2',
    messagingSenderId: '22819687623',
    projectId: 'xolv-43caf',
    databaseURL: 'https://xolv-43caf-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'xolv-43caf.firebasestorage.app',
    androidClientId: '22819687623-lk7e0mn8crs20s4ge0libn3vn0kf40j4.apps.googleusercontent.com',
    iosClientId: '22819687623-09q4dg4ollj21mcaej0eastdl3bhqg9m.apps.googleusercontent.com',
    iosBundleId: 'com.example.xolv',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = web;
}