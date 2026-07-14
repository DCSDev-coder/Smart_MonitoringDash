// Generated-like Firebase options for this app.
//
// We keep this file local so Firebase can initialize consistently on iOS,
// Android, and web without depending on plist/json bundle discovery.

import 'package:firebase_core/firebase_core.dart';
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
      default:
        return ios;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAnoPlaPA9kUOX5YIChT5M0_odKJQoD2us',
    authDomain: 'smartrack-f737a.firebaseapp.com',
    projectId: 'smartrack-f737a',
    storageBucket: 'smartrack-f737a.firebasestorage.app',
    messagingSenderId: '1042621674847',
    appId: '1:1042621674847:web:94c69b851c89a26f25f2ea',
    measurementId: 'G-XS3Z60L630',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBje8xv9-RBSGED9wMmmeQMLHKCi7xtwF8',
    appId: '1:1042621674847:android:a380acc542755fc225f2ea',
    messagingSenderId: '1042621674847',
    projectId: 'smartrack-f737a',
    storageBucket: 'smartrack-f737a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDnhV9GMFm-i7fplrv2bHwUru1aPotM6Tw',
    appId: '1:1042621674847:ios:feac5693c209b51f25f2ea',
    messagingSenderId: '1042621674847',
    projectId: 'smartrack-f737a',
    storageBucket: 'smartrack-f737a.firebasestorage.app',
    iosBundleId: 'my.dcstack.smartrack',
  );

  static const FirebaseOptions macos = ios;
}
