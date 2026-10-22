import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/firestore_quota.dart';

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

/// §104: the over-quota flag that pauses sync and shows the rider the
/// "database overloaded" strip.
void main() {
  test('isQuotaError is true only for resource-exhausted', () {
    expect(isQuotaError(firestoreError('resource-exhausted')), isTrue);
    expect(isQuotaError(firestoreError('unavailable')), isFalse);
    expect(isQuotaError(TimeoutException('probe')), isFalse);
  });

  test('a quota error pauses, and a second one does not notify again', () {
    final quota = FirestoreQuota();
    var notified = 0;
    quota.addListener(() => notified++);

    quota.report(firestoreError('resource-exhausted'));
    quota.report(firestoreError('resource-exhausted'));

    expect(quota.isPaused, isTrue);
    expect(notified, 1);
  });

  test('any other error leaves sync running', () {
    final quota = FirestoreQuota()
      ..report(firestoreError('unavailable'))
      ..report(TimeoutException('probe'));
    expect(quota.isPaused, isFalse);
  });

  test('resume clears the pause', () {
    final quota = FirestoreQuota()
      ..report(firestoreError('resource-exhausted'))
      ..resume();
    expect(quota.isPaused, isFalse);
  });

  test('firestorePausedProvider follows the shared instance', () {
    addTearDown(FirestoreQuota.instance.resume);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(firestorePausedProvider), isFalse);
    FirestoreQuota.instance.report(firestoreError('resource-exhausted'));
    expect(container.read(firestorePausedProvider), isTrue);
    FirestoreQuota.instance.resume();
    expect(container.read(firestorePausedProvider), isFalse);
  });
}
