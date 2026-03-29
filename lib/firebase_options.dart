// File generated manually. Replace with your actual config.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyAvkqAjZb-xkTtiLGcp1TvmG04PoN8cOSk',
    appId: '1:634672886656:web:054c863e24203372efc765',
    messagingSenderId: '634672886656',
    projectId: 'petfeeder-c22df',
    authDomain: 'petfeeder-c22df.firebaseapp.com',
    databaseURL: 'https://petfeeder-c22df-default-rtdb.firebaseio.com',
    storageBucket: 'petfeeder-c22df.firebasestorage.app',
    measurementId: 'G-VTT3S7DCSQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBim_TJnoSWo9vSCeLbD0N2ft-JbBG4-J8',
    appId: '1:634672886656:android:5e5b024bb39a0aa4efc765',
    messagingSenderId: '634672886656',
    projectId: 'petfeeder-c22df',
    databaseURL: 'https://petfeeder-c22df-default-rtdb.firebaseio.com',
    storageBucket: 'petfeeder-c22df.firebasestorage.app',
  );
}
