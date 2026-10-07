import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/widgets/auto_tracking_tile.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  testWidgets('AutoTrackingTile builds inside Material', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutoTrackingTile(),
          ),
        ),
      ),
    );

    // Initial render
    await tester.pumpAndSettle();

    expect(find.byType(AutoTrackingTile), findsOneWidget);
    
    // Check that it's wrapped in Material (since this was the fix in Group B)
    final materialFinder = find.ancestor(
      of: find.byType(SwitchListTile),
      matching: find.byType(Material),
    );
    expect(materialFinder, findsWidgets);
  });
}
