import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/forecast_strip.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §101.R10: labels at either end of the strip stayed outside the
/// Stack (left of 0, or past the right edge) where they couldn't be tapped.
void main() {
  test('labelLeft keeps the 80 px label inside [0, maxWidth - 80]', () {
    expect(ForecastStrip.labelLeft(14, 400), 0); // overdue, pinned left
    expect(ForecastStrip.labelLeft(200, 400), 160);
    expect(ForecastStrip.labelLeft(372, 400), 320); // at the horizon
    expect(ForecastStrip.labelLeft(10, 50), 0); // narrower than the label
  });

  testWidgets('an overdue item\'s label is fully inside the strip and tappable',
      (tester) async {
    String? pushed;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: ForecastStrip(bikeId: 'b1', forecasts: [
            CheckForecast(
              key: 'chain',
              serviceType: ServiceType.chain,
              status: ReminderStatus.overdue,
              kmLimit: 1000,
              baseKmLimit: 1000,
              kmLeft: -200,
            ),
          ]),
        ),
      ),
      GoRoute(
        path: '/home/maintenance/check',
        builder: (_, state) {
          pushed = state.uri.toString();
          return const Scaffold(body: Text('detail'));
        },
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    ));
    await tester.pumpAndSettle();

    final label = find.textContaining('hain');
    expect(label, findsOneWidget);
    expect(tester.getTopLeft(label).dx, greaterThanOrEqualTo(0));

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(pushed, contains('key=chain'));
  });
}
