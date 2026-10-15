import 'dart:ui';

import '../../l10n/app_localizations.dart';
import 'locale_provider.dart';

/// Localizations for code that has no `BuildContext` — a foreground-service
/// notification, say — resolved the way the app itself resolves them.
///
/// [chosen] is the rider's language setting (`appLocaleProvider`); `null` means
/// "follow the phone". Anything that is not Bangla falls back to English, which
/// is also `supportedLocales`' fallback, so an unsupported phone language cannot
/// make [lookupAppLocalizations] throw.
///
/// Not reactive: the result is a snapshot. Use `context.l10n` in widgets.
AppLocalizations resolveL10n(Locale? chosen) {
  final code = (chosen ?? PlatformDispatcher.instance.locale).languageCode;
  return lookupAppLocalizations(Locale(code == 'bn' ? 'bn' : 'en'));
}

/// [resolveL10n] for the rider's *saved* language setting, for services with no
/// `ref` (notifications). Still a snapshot: it reflects the setting at call time.
Future<AppLocalizations> savedL10n() async => resolveL10n(await readSavedLocale());
