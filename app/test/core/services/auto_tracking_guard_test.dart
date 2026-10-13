import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/auto_tracking_service.dart';

/// issues §101.C7: a throwing fix handler is logged and swallowed rather
/// than escaping as an uncaught async error in the foreground-task isolate.
void main() {
  test('guardedFix swallows and logs a thrown error', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = original);

    await expectLater(
      AutoTrackingService.guardedFix(() async => throw StateError('db gone')),
      completes,
    );
    expect(logs.single, contains('[auto-tracking] fix failed'));
    expect(logs.single, contains('db gone'));
  });

  test('guardedFix runs the handler', () async {
    var ran = false;
    await AutoTrackingService.guardedFix(() async => ran = true);
    expect(ran, isTrue);
  });
}
