import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/extensions/datetime_extensions.dart';

/// Issue #157: a queued comment/post/reply shows when it was written, not
/// when it reached the server, but only within the 48 h before server time.
void main() {
  final created = DateTime(2026, 10, 2, 14);

  test('shows writtenAt when it is within the 48 h before createdAt', () {
    final written = DateTime(2026, 10, 1, 20);
    expect(displayTime(created, written), written);
    expect(displayTime(created, created), created);
    final edge = created.subtract(const Duration(hours: 48));
    expect(displayTime(created, edge), edge);
  });

  test('falls back to createdAt when writtenAt is too old', () {
    final tooOld = created.subtract(const Duration(hours: 48, seconds: 1));
    expect(displayTime(created, tooOld), created);
  });

  test('falls back to createdAt when writtenAt is in the future', () {
    final future = created.add(const Duration(minutes: 1));
    expect(displayTime(created, future), created);
  });

  test('falls back to createdAt for old builds without writtenAt', () {
    expect(displayTime(created, null), created);
  });

  test('a pending write with no createdAt yet shows writtenAt', () {
    final written = DateTime(2026, 10, 1, 20);
    expect(displayTime(null, written), written);
    final before = DateTime.now();
    expect(displayTime(null, null).isBefore(before), isFalse);
  });
}
