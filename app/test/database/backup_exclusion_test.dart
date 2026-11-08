import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// iOS: the ride database and its side files are marked excluded from
/// iCloud/Finder backups after each open (Android: allowBackup="false").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('throttleiq/backup');
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('on iOS, asks to exclude the database and its side files', () async {
    await DatabaseHelper.excludeFromBackup('/docs/throttleiq.db', isIOS: true);
    expect(calls.single.method, 'excludeFromBackup');
    expect(calls.single.arguments, [
      '/docs/throttleiq.db',
      '/docs/throttleiq.db-wal',
      '/docs/throttleiq.db-shm',
      '/docs/throttleiq.db-journal',
    ]);
  });

  test('elsewhere, does nothing', () async {
    await DatabaseHelper.excludeFromBackup('/x/throttleiq.db', isIOS: false);
    expect(calls, isEmpty);
  });

  test('a missing channel (background engine) is not an error', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await DatabaseHelper.excludeFromBackup('/x/throttleiq.db', isIOS: true);
  });
}
