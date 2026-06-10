import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plataforma no soportada');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBI5zekXp0ygL9iYmha-k_UJuhL1jZa5E4',
    appId: '1:1037070117892:android:baeeadf6aa1eda35149951',
    messagingSenderId: '1037070117892',
    projectId: 'gymgram-6e226',
    storageBucket: 'gymgram-6e226.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgiyYHOY3ChdJGia5Fq-iw5NhoFm1H9vs',
    appId: '1:1037070117892:ios:2df07bef6e8ac90e149951',
    messagingSenderId: '1037070117892',
    projectId: 'gymgram-6e226',
    storageBucket: 'gymgram-6e226.firebasestorage.app',
    iosBundleId: 'com.gymgram.fit',
  );
}
