import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/auto_tracking_service.dart';

/// CrtiQue_Oct15 N5: ending or pausing a manual ride restarts auto-tracking
/// through start(), which used to re-ask for every missing permission. Only
/// turning auto-tracking on may ask.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const activity = MethodChannel('flutter_activity_recognition/method');
  const service = MethodChannel('flutter_foreground_task/methods');
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues(
        {AutoTrackingService.prefsEnabled: true});
    messenger.setMockMethodCallHandler(activity, (call) async {
      calls.add(call.method);
      return call.method == 'requestPermission' ? 'GRANTED' : 'DENIED';
    });
    messenger.setMockMethodCallHandler(service, (call) async {
      calls.add(call.method);
      return call.method == 'isRunningService' ? true : null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(activity, null);
    messenger.setMockMethodCallHandler(service, null);
  });

  test('a silent start never asks for a missing permission', () async {
    expect(await AutoTrackingService.instance.start(), isFalse);
    expect(calls, ['checkPermission']);
  });

  test('turning auto-tracking on asks for it', () async {
    expect(
        await AutoTrackingService.instance
            .start(askForMissingPermissions: true),
        isTrue);
    expect(calls, contains('requestPermission'));
  });
}
