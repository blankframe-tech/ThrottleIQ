import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/stats/presentation/widgets/ride_line_chart.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );

void main() {
  group('RideLineChart', () {
    testWidgets('labels the peak value on the y-axis side', (tester) async {
      await tester.pumpWidget(_host(
        const RideLineChart(values: [10, 42, 18], unit: 'km'),
      ));
      await tester.pump();

      expect(find.text('42 km'), findsOneWidget);
      // Only the peak is labelled — no axis ladder.
      expect(find.text('10 km'), findsNothing);
      expect(find.text('18 km'), findsNothing);
    });

    testWidgets('labels the first and last ride dates on the x-axis',
        (tester) async {
      await tester.pumpWidget(_host(RideLineChart(
        values: const [10, 42, 18],
        unit: 'km',
        dates: [
          DateTime(2026, 6, 12),
          DateTime(2026, 7, 4),
          DateTime(2026, 8, 1),
        ],
      )));
      await tester.pump();

      expect(find.text('12 Jun'), findsOneWidget);
      expect(find.text('1 Aug'), findsOneWidget);
      // The middle point is not labelled.
      expect(find.text('4 Jul'), findsNothing);
    });

    testWidgets('falls back to ride numbers when dates do not match the series',
        (tester) async {
      await tester.pumpWidget(_host(RideLineChart(
        values: const [10, 42, 18],
        dates: [DateTime(2026, 6, 12)],
      )));
      await tester.pump();

      expect(find.text('Ride 1'), findsOneWidget);
      expect(find.text('Ride 3'), findsOneWidget);
    });

    testWidgets('says so rather than drawing a one-point line', (tester) async {
      await tester.pumpWidget(_host(const RideLineChart(values: [10])));
      await tester.pump();

      expect(find.text('Not enough rides yet'), findsOneWidget);
    });

    testWidgets('survives an all-zero series', (tester) async {
      // Distance can legitimately be 0 for every ride in the window (a few
      // aborted recordings), which collapses the y range to nothing.
      await tester.pumpWidget(_host(
        const RideLineChart(values: [0, 0, 0], unit: 'km'),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
