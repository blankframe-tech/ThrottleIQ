import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Forced update: a build older than `config/app.minBuild` shows a blocking
/// "Update required" screen instead of the app (CrtiQue_Oct14 §10). Raising
/// `minBuild` in the Firebase console is how a rules change that old builds
/// can't survive gets shipped.

/// This build's number, the part after `+` in pubspec.yaml. scripts/deploy.sh
/// passes it as `--dart-define=APP_BUILD=<n>`.
///
/// shortcut: a build made without the define reads 0 and is never blocked;
/// switch to package_info_plus if releases are ever built outside deploy.sh.
const int kAppBuild = int.fromEnvironment('APP_BUILD');

/// Where riders get new builds (APK, Play beta and the iOS waitlist).
const String kInstallUrl = 'https://blankframe.tech/ThrottleIQ/install';

/// Whether [currentBuild] is older than [minBuild]. Fails open: an unknown
/// build (0) or a `minBuild` that is missing or not a number never blocks.
bool isUpdateRequired({required int currentBuild, required Object? minBuild}) =>
    currentBuild > 0 && minBuild is num && currentBuild < minBuild;

/// Reads `config/app` with [readConfig] and applies [isUpdateRequired].
/// Offline, slow (past [timeout]), denied or missing all mean "no update
/// required": a rider must never be locked out by a network problem.
Future<bool> checkUpdateRequired({
  required int currentBuild,
  required Future<Map<String, dynamic>?> Function() readConfig,
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (currentBuild <= 0) return false;
  try {
    final data = await readConfig().timeout(timeout);
    return isUpdateRequired(
      currentBuild: currentBuild,
      minBuild: data?['minBuild'],
    );
  } catch (e) {
    debugPrint('[update-gate] minBuild check skipped: $e');
    return false;
  }
}

/// Read once per app start. Loading and error both count as "no update
/// required", so the app is never held back waiting for it.
final updateRequiredProvider = FutureProvider<bool>(
  (ref) => checkUpdateRequired(
    currentBuild: kAppBuild,
    readConfig: () async =>
        (await FirebaseFirestore.instance.doc('config/app').get()).data(),
  ),
);
