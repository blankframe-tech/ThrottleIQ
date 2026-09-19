import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/screens/bike_detail_screen.dart';

/// The destructive path of bike removal (claude_sol §2.1.1): "Delete" stays
/// disabled until the rider types the bike's name.
void main() {
  final bike = BikeEntity(
    id: 'b',
    userId: 'alice',
    brand: 'Yamaha',
    model: 'FZ V3',
    year: 2022,
    rideCount: 12,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<List<bool?>> pump(WidgetTester tester) async {
    final results = <bool?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await showDialog<bool>(
            context: context,
            builder: (_) => TypeToDeleteBikeDialog(bike: bike),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  TextButton deleteButton(WidgetTester tester) => tester
      .widget<TextButton>(find.byKey(const Key('bike-delete-confirm')));

  testWidgets('Delete is disabled until the name matches', (tester) async {
    final results = await pump(tester);
    expect(find.textContaining('12 rides'), findsOneWidget);
    expect(deleteButton(tester).onPressed, isNull);

    await tester.enterText(
        find.byKey(const Key('bike-delete-confirm-field')), 'Yamaha');
    await tester.pump();
    expect(deleteButton(tester).onPressed, isNull);

    // Case and surrounding whitespace don't matter; the year isn't required.
    await tester.enterText(
        find.byKey(const Key('bike-delete-confirm-field')), '  yamaha fz v3 ');
    await tester.pump();
    expect(deleteButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('bike-delete-confirm')));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('Cancel returns false', (tester) async {
    final results = await pump(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
