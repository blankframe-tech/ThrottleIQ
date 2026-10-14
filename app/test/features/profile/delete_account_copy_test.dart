import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// CrtiQue_Oct14 B1: on Spark no function deletes cloud data, so the delete
/// dialog must say it is done by hand within 30 days, and how to ask.
/// Matches privacy.html §9 and the account deletion runbook in DOCS.
void main() {
  test('the delete-account dialog states the manual 30-day deletion', () {
    for (final s in [
      AppLocalizationsEn().thisActionIrreversibleAll,
      AppLocalizationsBn().thisActionIrreversibleAll,
    ]) {
      expect(s, contains('30'));
      expect(s, contains('hello@blankframe.tech'));
    }
    expect(AppLocalizationsEn().thisActionIrreversibleAll, contains('by hand'));
  });
}
