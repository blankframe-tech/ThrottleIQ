import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return ios;
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummyAPIKeyForDevelopment',
    appId: '1:1234567890:ios:abcdefghijklmnopqr',
    messagingSenderId: '1234567890',
    projectId: 'throttleiq-dummy',
    storageBucket: 'throttleiq-dummy.appspot.com',
    iosBundleId: 'com.throttleiq.throttleiq',
  );
}
