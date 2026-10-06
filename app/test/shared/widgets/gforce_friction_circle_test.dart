import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/shared/widgets/gforce_friction_circle.dart';

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
  group('GForceFrictionCircle', () {
    testWidgets('renders zero G-Force state cleanly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GForceFrictionCircle(
            lateralG: 0.0,
            longitudinalG: 0.0,
          ),
        ),
      );

      expect(find.byType(GForceFrictionCircle), findsOneWidget);
      expect(find.text('0.00g'), findsOneWidget);
      expect(find.text('TRACTION ENVELOPE'), findsOneWidget);
    });

    testWidgets('renders combined lateral and longitudinal G values with custom subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GForceFrictionCircle(
            lateralG: 0.6,
            longitudinalG: 0.8,
            subtitle: 'CORNERING LOAD',
          ),
        ),
      );

      // sqrt(0.36 + 0.64) = 1.00g
      expect(find.text('1.00g'), findsOneWidget);
      expect(find.text('CORNERING LOAD'), findsOneWidget);
    });
  });
}
