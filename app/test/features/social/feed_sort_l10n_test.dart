import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/feed_sort.dart';
import 'package:throttleiq/features/social/presentation/feed_sort_l10n.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

void main() {
  test('English matches the domain label for every sort', () {
    final en = AppLocalizationsEn();
    for (final s in FeedSort.values) {
      expect(s.localizedLabel(en), s.label, reason: '$s');
    }
  });

  test('Bangla never falls back to English', () {
    final bn = AppLocalizationsBn();
    for (final s in FeedSort.values) {
      expect(s.localizedLabel(bn), isNot(s.label), reason: '$s');
    }
  });
}
