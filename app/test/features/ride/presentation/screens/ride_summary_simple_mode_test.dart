import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/features/ride/presentation/screens/ride_summary_screen.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

import '../../../../key_screens.dart';

/// Simple mode (#240) keeps the post-ride summary but drops the power-user
/// JSON/GPX/CSV export row. (Save as route sits on the map overlay, which
/// the key-screen fixture doesn't draw: it has no track points.)
void main() {
  setUpAll(loadKeyScreenFonts);
  final en = AppLocalizationsEn();

  testWidgets('the export row shows in full mode and hides in Simple mode',
      (tester) async {
    await pumpKeyScreen(tester, KeyScreen.rideSummary);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(RideSummaryScreen)));

    final exports = [
      en.telemetrySectionLabel.toUpperCase(),
      en.exportJsonAction,
      en.exportGpxAction,
      en.exportCsvAction,
    ];
    for (final t in exports) {
      expect(find.text(t, skipOffstage: false), findsOneWidget, reason: t);
    }

    await container
        .read(appModulesProvider.notifier)
        .set(const AppModules(simple: true));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final t in exports) {
      expect(find.text(t, skipOffstage: false), findsNothing, reason: t);
    }
    // The rest of the summary is still there.
    expect(find.text(en.deleteRide, skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
