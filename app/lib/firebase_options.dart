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
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'this project only ships Android and iOS.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform: '
          '$defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqefnntNovy6QFcc0N6KJeIJ6wym4J1dU',
    appId: '1:603325098273:android:94694220f44cbf63fcf660',
    messagingSenderId: '603325098273',
    projectId: 'throttleiqfb',
    storageBucket: 'throttleiqfb.firebasestorage.app',
    androidClientId:
        '603325098273-stdklad1unrlni5nsg96ckmc5tdbl19s.apps.googleusercontent.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDRjGyrJ0RPuQYLegbCZ4_wkpsHB_pfQVA',
    appId: '1:603325098273:ios:0f2907197737692efcf660',
    messagingSenderId: '603325098273',
    projectId: 'throttleiqfb',
    storageBucket: 'throttleiqfb.firebasestorage.app',
    iosBundleId: 'com.bft.throttleiq',
    iosClientId:
        '603325098273-gkjts7olcqevdkc1kiful0gtjspfe0bv.apps.googleusercontent.com',
  );
}
