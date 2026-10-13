import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/consumables_health_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark().copyWith(
      extensions: [
        AppColorPalette.sportDark,
        AppShapeProfile.forVibe(AppShapeVibe.boxy),
      ],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ConsumablesHealthCard', () {
    testWidgets('renders cleanly with empty forecasts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConsumablesHealthCard(
            forecasts: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConsumablesHealthCard), findsOneWidget);
      expect(find.text('MACHINE VITALS'), findsOneWidget);
      expect(find.text('WEAR MONITOR'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(4));
    });

    testWidgets('renders wear levels and handles tap callback', (tester) async {
      ServiceType? tappedType;

      final forecasts = [
        const CheckForecast(
          key: 'oilChange',
          serviceType: ServiceType.oilChange,
          status: ReminderStatus.ok,
          kmLimit: 5000,
          baseKmLimit: 5000,
          kmLeft: 2500, // 50%
        ),
        const CheckForecast(
          key: 'chain',
          serviceType: ServiceType.chain,
          status: ReminderStatus.dueSoon,
          kmLimit: 1000,
          baseKmLimit: 1000,
          kmLeft: 100, // 10%
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          ConsumablesHealthCard(
            forecasts: forecasts,
            onSelectConsumable: (type) => tappedType = type,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);

      // Tap on Engine Oil gauge
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();

      expect(tappedType, ServiceType.oilChange);
    });
  });
}
