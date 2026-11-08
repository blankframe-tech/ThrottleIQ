import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/services/notification_service.dart';

/// The lock-screen (full-screen intent) permission is only for crash alerts.
/// While they are compiled off, riders are not sent to grant it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    // Set before NotificationService first builds its plugin, which picks
    // the Android implementation from the target platform.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'requestPermissions skips the full-screen intent ask while crash '
      'alerts are off', () async {
    expect(SensorConstants.crashAlertsEnabled, isFalse);
    expect(await NotificationService.instance.requestPermissions(), isTrue);
    expect(calls, contains('requestNotificationsPermission'));
    expect(calls, isNot(contains('requestFullScreenIntentPermission')));
  });
}
