import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badges.dart';
import 'package:throttleiq/features/stats/presentation/badge_l10n.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// Badge text is localized by stable id in the presentation layer, while the
/// English copy stays in the domain. These tests catch the two ways that can
/// drift: a family/rung added without a key, and a translation that quietly
/// changes what the English says.
void main() {
  final en = AppLocalizationsEn();
  final bn = AppLocalizationsBn();

  test('English localization reproduces the domain copy exactly', () {
    for (final f in badgeFamilies) {
      expect(f.localizedName(en), f.name, reason: f.id);
      expect(f.localizedAbout(en), f.about, reason: f.id);
      expect(f.localizedUnit(en), f.unit, reason: f.id);
      for (final t in f.tiers) {
        expect(f.localizedRequirementFor(en, t.threshold),
            f.requirementFor(t.threshold),
            reason: '${f.id} ${t.id}');
        expect(t.localizedName(en), t.name, reason: t.id);
      }
    }
  });

  test('every tier label is localized', () {
    for (final t in BadgeTier.values) {
      expect(t.localizedLabel(en), t.label);
      expect(t.localizedLabel(bn), isNot(t.label));
    }
  });

  test('Bangla never falls back to the English domain text', () {
    for (final f in badgeFamilies) {
      expect(f.localizedName(bn), isNot(f.name), reason: f.id);
      expect(f.localizedAbout(bn), isNot(f.about), reason: f.id);
      for (final t in f.tiers) {
        expect(f.localizedRequirementFor(bn, t.threshold),
            isNot(f.requirementFor(t.threshold)),
            reason: '${f.id} ${t.id}');
        expect(f.localizedRequirementFor(bn, t.threshold), isNot(contains('{n}')));
        // "100 km" and "3-day streak" differ only by digits/units, so compare
        // against the English name rather than demanding new words.
        expect(t.localizedName(bn), isNot(t.name), reason: t.id);
      }
    }
  });
}
