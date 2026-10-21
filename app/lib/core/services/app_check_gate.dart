import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Sideload gate: an Android release build that App Check rejects (Play
/// Integrity: not installed from Google Play) shows a blocking "Install from
/// Google Play" screen instead of an app whose Firestore calls all fail once
/// enforcement is on (DOCS/app_check.md). iOS and debug-provider builds are
/// never blocked.

/// `--dart-define=APP_CHECK_DEBUG=true` makes a release build use the App
/// Check debug provider, so a development-signed `flutter run --release` can
/// pass once its debug token is registered in the console.
const bool kAppCheckDebugDefine = bool.fromEnvironment('APP_CHECK_DEBUG');

/// Debug builds, and release builds with [kAppCheckDebugDefine], use the
/// debug provider.
const bool kUsesAppCheckDebugProvider = kDebugMode || kAppCheckDebugDefine;

const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.bft.throttleiq';
const String kTestingWhatsAppUrl =
    'https://wa.me/8801327045005?text=ThrottleIQ%20testing%20request';

/// The Play Store's installer package name (PackageInfo.installerStore).
const String _playInstaller = 'com.android.vending';

/// True only for the App Check backend refusing the attestation ("App
/// attestation failed", HTTP 403). Network errors, timeouts, a disabled App
/// Check API (`SERVICE_DISABLED`, also a 403) and anything unknown are false,
/// so a rider is never locked out by a bad connection or a console mistake.
bool isAttestationRejection(Object error) =>
    error.toString().toLowerCase().contains('attestation failed');

/// Whether to show the sideload screen. [tokenError] is what fetching the App
/// Check token threw, or null if it worked.
bool shouldBlockSideload({
  required bool isAndroid,
  required bool usesDebugProvider,
  required String? installerStore,
  required Object? tokenError,
}) =>
    isAndroid &&
    !usesDebugProvider &&
    installerStore != _playInstaller &&
    tokenError != null &&
    isAttestationRejection(tokenError);

/// Fetches a token with [getToken] and applies [shouldBlockSideload]. A token
/// slower than [timeout] counts as transient and does not block. Play installs
/// skip the fetch: the screen would tell them to do what they already did.
Future<bool> checkSideloadBlocked({
  required bool isAndroid,
  required bool usesDebugProvider,
  required Future<String?> Function() installerStore,
  required Future<String?> Function() getToken,
  Duration timeout = const Duration(seconds: 15),
}) async {
  if (!isAndroid || usesDebugProvider) return false;
  final String? installer;
  try {
    installer = await installerStore();
  } catch (e) {
    debugPrint('[app-check-gate] installer unknown, not blocking: $e');
    return false;
  }
  if (installer == _playInstaller) return false;
  Object? error;
  try {
    await getToken().timeout(timeout);
  } on TimeoutException catch (e) {
    debugPrint('[app-check-gate] token timed out, not blocking: $e');
    return false;
  } catch (e) {
    error = e;
    debugPrint('[app-check-gate] token failed: $e');
  }
  return shouldBlockSideload(
    isAndroid: isAndroid,
    usesDebugProvider: usesDebugProvider,
    installerStore: installer,
    tokenError: error,
  );
}

/// Checked once per app start. Loading and error both mean "not blocked".
final sideloadBlockedProvider = FutureProvider<bool>(
  (ref) => checkSideloadBlocked(
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    usesDebugProvider: kUsesAppCheckDebugProvider,
    installerStore: () async =>
        (await PackageInfo.fromPlatform()).installerStore,
    getToken: () => FirebaseAppCheck.instance.getToken(),
  ),
);
