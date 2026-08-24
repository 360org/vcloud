import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

class VCloudFirebaseOptions {
  VCloudFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyAFEPKxCmxL5dtKAZD1Xt4d7XiWoHDQ6UY',
        appId: '1:339448653254:web:1e9d9ec9460c30ce073ec7',
        messagingSenderId: '339448653254',
        projectId: 'vcloud-mobile',
        authDomain: 'vcloud-mobile.firebaseapp.com',
        storageBucket: 'vcloud-mobile.firebasestorage.app',
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const FirebaseOptions(
        apiKey: 'AIzaSyCoJkAiaYYSzSBNg_K3_9TQiafNZXaPt4c',
        appId: '1:339448653254:android:de3ff342a41f4927073ec7',
        messagingSenderId: '339448653254',
        projectId: 'vcloud-mobile',
        storageBucket: 'vcloud-mobile.firebasestorage.app',
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => const FirebaseOptions(
        apiKey: 'AIzaSyAGNzfj69cnQeb8GWqRUbfS3ALpDSKyTyk',
        appId: '1:339448653254:ios:2fda2a0e8e2922de073ec7',
        messagingSenderId: '339448653254',
        projectId: 'vcloud-mobile',
        iosBundleId: 'com.w360s.wcloudapp',
        storageBucket: 'vcloud-mobile.firebasestorage.app',
      ),
      _ => const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
      ),
    };
  }
}
