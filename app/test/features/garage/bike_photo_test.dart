import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/presentation/widgets/bike_photo.dart';

/// [BikePhoto] renders a *local device file path* that the app cannot trust:
/// it may be null (never set, or nulled out by `CloudRepository.downloadBikes`
/// for a bike pulled from another device) and it may point at a file that has
/// since been deleted. Neither case may produce a broken/red image box, so
/// both must resolve to the generic motorcycle icon.
void main() {
  final fallbackIcon = find.byIcon(Icons.two_wheeler);

  Future<void> pumpPhoto(WidgetTester tester, String? path) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BikePhoto(imagePath: path, width: 44, height: 44),
        ),
      ),
    );
  }

  testWidgets('falls back to the bike icon when imagePath is null',
      (tester) async {
    await pumpPhoto(tester, null);

    expect(fallbackIcon, findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('falls back to the bike icon when imagePath is empty',
      (tester) async {
    await pumpPhoto(tester, '');

    expect(fallbackIcon, findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('falls back to the bike icon when the file no longer exists',
      (tester) async {
    final missing =
        '${Directory.systemTemp.path}/throttleiq_no_such_bike_photo.jpg';
    // Guard against a stale file from an earlier run making this vacuous.
    expect(File(missing).existsSync(), isFalse);

    // runAsync: FileImage does *real* file I/O, which the test binding's fake
    // async clock will never complete on its own — without this the decode
    // failure (and therefore errorBuilder) never happens.
    await tester.runAsync(() async {
      await pumpPhoto(tester, missing);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(fallbackIcon, findsOneWidget);
  });

  testWidgets('renders the photo when the file is readable', (tester) async {
    // A real 1x1 PNG, so this proves the widget actually attempts the rider's
    // photo rather than always short-circuiting to the icon.
    final file = File('${Directory.systemTemp.path}/throttleiq_bike_photo.png')
      ..writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4'
          '2mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    await tester.runAsync(() async {
      await pumpPhoto(tester, file.path);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    // Decoded successfully, so no fallback — this is the happy path the
    // errorBuilder tests above are the counterpoint to.
    expect(fallbackIcon, findsNothing);
  });
}
