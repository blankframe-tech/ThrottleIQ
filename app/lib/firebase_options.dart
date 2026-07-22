import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return ios;
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDRjGyrJ0RPuQYLegbCZ4_wkpsHB_pfQVA',
    appId: '1:603325098273:ios:f65fac5586eebda3fcf660',
    messagingSenderId: '603325098273',
    projectId: 'throttleiqfb',
    storageBucket: 'throttleiqfb.firebasestorage.app',
    iosBundleId: 'com.throttleiq.throttleiq',
    iosClientId:
        '603325098273-gdefaanvp7u5e2d04f6uva4r888vuncq.apps.googleusercontent.com',
  );
}
