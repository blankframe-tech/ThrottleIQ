// Text antialiasing differs between macOS and Linux, so these PNGs (made on
// the owner's Mac) only match on macOS; CI (ubuntu) skips the file.
@TestOn('mac-os')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'key_screens.dart';

/// #49: screenshots of stable key screens in both themes, with the app's
/// real fonts. Update after an intended visual change with
/// `flutter test --update-goldens test/key_screens_golden_test.dart`.
void main() {
  setUpAll(loadKeyScreenFonts);

  for (final screen in const [
    KeyScreen.cockpit,
    KeyScreen.login,
    KeyScreen.advancedSettings,
  ]) {
    for (final brightness in Brightness.values) {
      final name = '${screen.name}_${brightness.name}';
      testWidgets(name, (tester) async {
        await pumpKeyScreen(tester, screen, brightness: brightness);
        // Map tiles decode on the real clock: let them land so the shot
        // doesn't depend on timing.
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        await expectLater(
            find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      });
    }
  }
}
