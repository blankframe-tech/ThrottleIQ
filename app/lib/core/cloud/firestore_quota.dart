import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/error_reporter.dart';

/// Whether [error] is Firestore refusing work because the project's daily
/// quota is spent. On Spark that is 50,000 reads, 20,000 writes or 20,000
/// deletes a day, reset around midnight Pacific (issues §104).
bool isQuotaError(Object error) =>
    error is FirebaseException && error.code == 'resource-exhausted';

/// App-wide "Firestore is over its daily quota" flag.
///
/// While it is set, [SyncManager] skips its passes and [OutboxService] stops
/// delivering. Every attempt would be refused anyway, and each one would burn
/// an outbox retry (an entry is retired after 20) or stack another copy of the
/// same write in the SDK's queue to replay at the reset. Rider data stays on
/// the phone meanwhile. SyncManager's quota probe clears the flag once
/// Firestore answers again, and sync carries on where it stopped.
///
/// shortcut: one flag for reads and writes, because reads run out first on
/// Spark (load test §104). On Blaze `resource-exhausted` is a short rate
/// limit, not a day-long lockout; revisit this if the project moves.
class FirestoreQuota extends ValueNotifier<bool> {
  FirestoreQuota() : super(false);

  static final FirestoreQuota instance = FirestoreQuota();

  bool get isPaused => value;

  /// Pauses on a quota error and ignores anything else. Reported to
  /// Crashlytics once per outage, so the console shows who hit it and when.
  void report(Object error, [StackTrace? stack]) {
    if (!isQuotaError(error) || value) return;
    value = true;
    reportNonFatal(error, stack, reason: 'Firestore over its daily quota');
  }

  void resume() => value = false;
}

/// True while Firestore is over quota. Drives `OverQuotaBar`.
final firestorePausedProvider = Provider<bool>((ref) {
  final quota = FirestoreQuota.instance;
  void onChange() => ref.invalidateSelf();
  quota.addListener(onChange);
  ref.onDispose(() => quota.removeListener(onChange));
  return quota.isPaused;
});
