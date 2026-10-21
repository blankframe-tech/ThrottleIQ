import 'dart:async';

import 'outbox_service.dart' show kOutboxAttemptTimeout;

/// Waits at most [timeout] for a Firestore write's server ack (issues §104.6).
///
/// The SDK queues a write locally before it is sent, so a timeout means
/// "saved on this phone, lands when the server takes it" (offline, or the
/// daily write quota is spent and the write waits for the reset), not a
/// failure. A screen that awaited the bare write used to hang on its spinner
/// until then. Returns false on a timeout; any other error is rethrown.
Future<bool> ackOrQueued(
  Future<void> write, {
  Duration timeout = kOutboxAttemptTimeout,
}) async {
  try {
    await write.timeout(timeout);
    return true;
  } on TimeoutException {
    return false;
  }
}
