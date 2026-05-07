import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS no configurado aún — falta GoogleService-Info.plist');
      default:
        throw UnsupportedError('Plataforma no soportada');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBI5zekXp0ygL9iYmha-k_UJuhL1jZa5E4',
    appId: '1:1037070117892:android:f79929b743493ca4149951',
    messagingSenderId: '1037070117892',
    projectId: 'gymgram-6e226',
    storageBucket: 'gymgram-6e226.firebasestorage.app',
  );
}
