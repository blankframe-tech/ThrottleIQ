import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/write_ack.dart';

/// `ackOrQueued` (issues §104.6): a screen waits a bounded time for a
/// Firestore write, then treats it as queued instead of hanging.
void main() {
  const short = Duration(milliseconds: 20);

  test('an acked write returns true', () async {
    expect(await ackOrQueued(Future<void>.value(), timeout: short), isTrue);
  });

  test('a write that never acks returns false after the timeout', () async {
    final never = Completer<void>().future;
    final sw = Stopwatch()..start();
    expect(await ackOrQueued(never, timeout: short), isFalse);
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('a rejected write still throws', () async {
    expect(
      ackOrQueued(Future<void>.error(StateError('permission-denied')),
          timeout: short),
      throwsStateError,
    );
  });

  test('a rejection after the timeout is not an unhandled error', () async {
    final pending = Completer<void>();
    expect(await ackOrQueued(pending.future, timeout: short), isFalse);
    pending.completeError(StateError('rejected later'));
    await Future<void>.delayed(short);
  });
}
