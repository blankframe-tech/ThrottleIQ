import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/data/repositories/profile_repository.dart';

/// A public @handle must not reveal the rider's email address: the default
/// is a neutral `rider_xxxxxx`, and riders opt into their own handle.
void main() {
  test('is rider_ plus six lowercase letters or digits', () {
    for (var i = 0; i < 200; i++) {
      expect(defaultUsername(), matches(RegExp(r'^rider_[a-z0-9]{6}$')));
    }
  });

  test('passes the same check setUsername applies', () {
    expect(defaultUsername(), matches(RegExp(r'^[a-z0-9_]{3,20}$')));
  });

  test('contains no part of the email', () {
    const email = 'rahim.uddin123@example.com';
    final handle = defaultUsername(Random(1));
    for (final part in email.split(RegExp(r'[@.]|(?<=[a-z])(?=\d)'))) {
      expect(handle.contains(part), isFalse, reason: part);
    }
  });

  test('two new riders get different handles', () {
    expect(defaultUsername(Random(1)), isNot(defaultUsername(Random(2))));
  });
}
