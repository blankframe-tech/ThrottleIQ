import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/shared/widgets/dual_lean_arc_gauge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      extensions: [
        AppColorPalette.sportDark,
        AppShapeProfile.forVibe(AppShapeVibe.boxy),
      ],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('DualLeanArcGauge', () {
    testWidgets('renders zero lean angle cleanly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DualLeanArcGauge(
            leftAngle: 0,
            rightAngle: 0,
          ),
        ),
      );

      expect(find.byType(DualLeanArcGauge), findsOneWidget);
      expect(find.text('0°'), findsOneWidget);
      expect(find.text('STREET'), findsOneWidget);
    });

    testWidgets('renders active left lean with arrow and subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DualLeanArcGauge(
            leftAngle: 42.4,
            rightAngle: 12.1,
            peakLeftAngle: 45.0,
            peakRightAngle: 38.0,
            subtitle: 'HAIRPIN ENTRY',
          ),
        ),
      );

      expect(find.text('42°'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_left), findsOneWidget);
      expect(find.text('HAIRPIN ENTRY'), findsOneWidget);
    });

    testWidgets('renders active right lean angle with right arrow and rating', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DualLeanArcGauge(
            leftAngle: 10.0,
            rightAngle: 35.6,
          ),
        ),
      );

      expect(find.text('36°'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);
      expect(find.text('SPORT'), findsOneWidget);
    });

    testWidgets('renders extreme lean with knee down rating', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DualLeanArcGauge(
            leftAngle: 48.0,
            rightAngle: 0,
          ),
        ),
      );

      expect(find.text('48°'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_left), findsOneWidget);
      expect(find.text('KNEE DOWN'), findsOneWidget);
    });
  });
}
