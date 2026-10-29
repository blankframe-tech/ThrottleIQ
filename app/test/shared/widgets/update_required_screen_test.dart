import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/shared/widgets/update_required_screen.dart';

/// #38: a rider on a blocked build can still take their rides with them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  final shared = <MethodCall>[];

  setUp(() {
    shared.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      shared.add(call);
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  Future<void> pump(
          WidgetTester tester, Future<List<File>> Function() export) =>
      tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UpdateRequiredScreen(exportRides: export),
      ));

  final button = find.byKey(const Key('update-required-export-rides'));

  testWidgets('Export my rides shares the exported files', (tester) async {
    final file = File('${Directory.systemTemp.path}/ride_r1.gpx');
    var calls = 0;
    await pump(tester, () async {
      calls++;
      return [file];
    });

    expect(find.text('Export my rides'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(shared, hasLength(1));
    expect(shared.single.method, 'shareFiles');
    expect((shared.single.arguments as Map)['paths'], [file.path]);
  });

  testWidgets('says so when there is nothing to export', (tester) async {
    await pump(tester, () async => []);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('There are no rides on this phone to export.'),
        findsOneWidget);
    expect(shared, isEmpty);
  });

  testWidgets('a failed export shows an error instead of nothing',
      (tester) async {
    await pump(tester, () async => throw const FileSystemException('disk'));
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Export failed'), findsOneWidget);
  });
}
