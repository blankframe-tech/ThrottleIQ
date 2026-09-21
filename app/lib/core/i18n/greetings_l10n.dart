import 'dart:math' as math;

import '../../l10n/app_localizations.dart';
import '../utils/greetings.dart';

/// Localized greetings and taglines for the Record screen.
///
/// `greetings.dart` stays a pure English module (tested with a seeded RNG). A
/// rider's language can change and `initState` cannot read localizations, so
/// the screen picks a language-independent *choice* once ([pickGreeting],
/// [pickQuoteIndex]) and resolves the words at build time — which also means a
/// live language switch re-words the line without re-rolling it.

/// Which greeting was picked: a time-of-day bucket and a variant within it.
typedef GreetingPick = ({GreetingBucket bucket, int index});

const int _variantsPerBucket = 5;
const int kQuoteCount = 16;

GreetingPick pickGreeting(DateTime now, {math.Random? random}) => (
      bucket: greetingBucketFor(now),
      index: (random ?? math.Random()).nextInt(_variantsPerBucket),
    );

int pickQuoteIndex({math.Random? random}) =>
    (random ?? math.Random()).nextInt(kQuoteCount);

/// Resolves [pick] in [l10n]'s language, weaving in [name] where the variant has
/// a slot for it (a blank or literal "null" name falls back to a generic word).
Greeting resolveGreeting(GreetingPick pick, AppLocalizations l10n, {String? name}) {
  final trimmed = name?.trim() ?? '';
  final safe = (trimmed.isEmpty || trimmed.toLowerCase() == 'null')
      ? l10n.greetingNameFallback
      : trimmed;
  final variants = _variants(pick.bucket, l10n, safe);
  final v = variants[pick.index];
  return (line: v.$1, usesName: v.$2);
}

/// The two halves of tagline [index], to be joined with a space.
(String, String) resolveQuote(int index, AppLocalizations l10n) => _quotes(l10n)[index];

List<(String, bool)> _variants(GreetingBucket b, AppLocalizations l, String n) => switch (b) {
      GreetingBucket.lateNight => [
          (l.greetLateNight1, false),
          (l.greetLateNight2, false),
          (l.greetLateNight3, false),
          (l.greetLateNight4(n), true),
          (l.greetLateNight5, false),
        ],
      GreetingBucket.earlyMorning => [
          (l.greetEarlyMorning1, false),
          (l.greetEarlyMorning2, false),
          (l.greetEarlyMorning3, false),
          (l.greetEarlyMorning4(n), true),
          (l.greetEarlyMorning5, false),
        ],
      GreetingBucket.morning => [
          (l.greetMorning1(n), true),
          (l.greetMorning2, false),
          (l.greetMorning3, false),
          (l.greetMorning4, false),
          (l.greetMorning5(n), true),
        ],
      GreetingBucket.afternoon => [
          (l.greetAfternoon1(n), true),
          (l.greetAfternoon2, false),
          (l.greetAfternoon3, false),
          (l.greetAfternoon4(n), true),
          (l.greetAfternoon5, false),
        ],
      GreetingBucket.evening => [
          (l.greetEvening1(n), true),
          (l.greetEvening2, false),
          (l.greetEvening3(n), true),
          (l.greetEvening4, false),
          (l.greetEvening5, false),
        ],
      GreetingBucket.night => [
          (l.greetNight1, false),
          (l.greetNight2, false),
          (l.greetNight3(n), true),
          (l.greetNight4, false),
          (l.greetNight5(n), true),
        ],
    };

List<(String, String)> _quotes(AppLocalizations l) => [
      (l.quote0Setup, l.quote0Payoff),
      (l.quote1Setup, l.quote1Payoff),
      (l.quote2Setup, l.quote2Payoff),
      (l.quote3Setup, l.quote3Payoff),
      (l.quote4Setup, l.quote4Payoff),
      (l.quote5Setup, l.quote5Payoff),
      (l.quote6Setup, l.quote6Payoff),
      (l.quote7Setup, l.quote7Payoff),
      (l.quote8Setup, l.quote8Payoff),
      (l.quote9Setup, l.quote9Payoff),
      (l.quote10Setup, l.quote10Payoff),
      (l.quote11Setup, l.quote11Payoff),
      (l.quote12Setup, l.quote12Payoff),
      (l.quote13Setup, l.quote13Payoff),
      (l.quote14Setup, l.quote14Payoff),
      (l.quote15Setup, l.quote15Payoff),
    ];
