import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_check_gate.dart' show kPlayStoreUrl;

/// Forced update: a build older than `config/app.minBuild` shows a blocking
/// "Update required" screen instead of the app (CrtiQue_Oct14 §10). Raising
/// `minBuild` in the Firebase console is how a rules change that old builds
/// can't survive gets shipped.

/// This build's number: the part after `+` in pubspec.yaml, which Flutter
/// writes into the Android versionCode and the iOS CFBundleVersion. Per-ABI
/// APKs carry the same number (build.gradle.kts resets Flutter's
/// abi * 1000 + build). 0 when it can't be read, which never blocks.
Future<int> currentBuildNumber() async {
  try {
    return int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
  } catch (e) {
    debugPrint('[update-gate] build number unavailable: $e');
    return 0;
  }
}

/// Where riders get new builds (APK, Play beta and the iOS waitlist).
const String kInstallUrl = 'https://throttleiqfb.web.app/install';

/// The Year in Review share card's QR: the public install page, tagged so
/// installs from shared cards can be counted. The Play listing 404s for
/// non-testers until production access.
const String kYearInReviewInstallUrl =
    'https://www.blankframe.tech/throttle-iq/install/?c=yir';

/// Whether [currentBuild] is older than [minBuild]. Fails open: an unknown
/// build (0) or a `minBuild` that is missing or not a number never blocks.
bool isUpdateRequired({required int currentBuild, required Object? minBuild}) =>
    currentBuild > 0 && minBuild is num && currentBuild < minBuild;

/// Live: re-evaluates every time `config/app` changes, so raising `minBuild`
/// in the console reaches riders who already have the app open. Errors
/// (offline, denied, App Check) are dropped and never block: a rider must
/// never be locked out by a network problem.
Stream<bool> watchUpdateRequired({
  required int currentBuild,
  required Stream<Map<String, dynamic>?> config,
}) {
  if (currentBuild <= 0) return Stream.value(false);
  return config
      .map((data) => isUpdateRequired(
            currentBuild: currentBuild,
            minBuild: data?['minBuild'],
          ))
      .handleError(
          (Object e) => debugPrint('[update-gate] minBuild check skipped: $e'));
}

/// Where the update screen sends the rider: Google Play on Android.
/// shortcut: iOS has no App Store listing (personal team), so it gets the
/// install page; use the App Store URL once the app is listed.
String updateUrlFor(TargetPlatform platform) =>
    platform == TargetPlatform.android ? kPlayStoreUrl : kInstallUrl;

/// Loading and error both count as "no update required" (app.dart reads
/// `valueOrNull ?? false`), so the app is never held back waiting for it.
final updateRequiredProvider = StreamProvider<bool>(
  (ref) async* {
    yield* watchUpdateRequired(
      currentBuild: await currentBuildNumber(),
      config: FirebaseFirestore.instance
          .doc('config/app')
          .snapshots()
          .map((snap) => snap.data()),
    );
  },
);
