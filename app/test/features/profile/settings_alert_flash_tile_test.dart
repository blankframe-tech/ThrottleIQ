import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/profile/presentation/widgets/settings_alert_flash_tile.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Settings → Ride tracking: the cockpit alert flash toggle (#32).
void main() {
  testWidgets('on by default; turning it off is saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SettingsAlertFlashTile()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings_alert_flash'), isFalse);
  });
}
