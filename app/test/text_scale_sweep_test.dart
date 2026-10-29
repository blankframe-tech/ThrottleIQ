import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'key_screens.dart';

/// #48 / §83.22: every key screen at the OS text sizes riders use, in both
/// languages, with the app's real fonts. A `RenderFlex overflowed` (or any
/// other layout error) fails the test on its own, and the log names the
/// widget that overflowed. `_ClampedTextScale` in app.dart may only be raised
/// to a scale this passes.
void main() {
  setUpAll(loadKeyScreenFonts);

  for (final locale in const [Locale('en'), Locale('bn')]) {
    for (final screen in KeyScreen.values) {
      for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
        testWidgets('${screen.name} at ${scale}x (${locale.languageCode})',
            (tester) async {
          await pumpKeyScreen(tester, screen, textScale: scale, locale: locale);
        });
      }
    }
  }
}
