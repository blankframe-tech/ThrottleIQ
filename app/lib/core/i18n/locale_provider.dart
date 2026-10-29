import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

const _prefsKey = 'locale';
const _systemValue = 'system';
const _englishValue = 'en';
const _banglaValue = 'bn';

/// The rider's language choice.
///
/// [system] is deliberately distinct from [english]: "follow the phone" and
/// "pin to English" look identical on an English handset but diverge the
/// moment the rider switches their phone to Bangla, and we want that switch
/// to carry through unless they explicitly opted out of it.
enum AppLocale {
  system,
  english,
  bangla;

  /// The [Locale] to hand [WidgetsApp.locale], or `null` to defer to the
  /// platform (which then resolves against `supportedLocales`).
  Locale? get toLocale => switch (this) {
        AppLocale.system => null,
        AppLocale.english => const Locale('en'),
        AppLocale.bangla => const Locale('bn'),
      };

  String get _prefsValue => switch (this) {
        AppLocale.system => _systemValue,
        AppLocale.english => _englishValue,
        AppLocale.bangla => _banglaValue,
      };

  static AppLocale _fromPrefs(String? value) => switch (value) {
        _englishValue => AppLocale.english,
        _banglaValue => AppLocale.bangla,
        // Includes null (never chosen) and any value written by a future
        // version that added a language this build doesn't know about —
        // falling back to the phone is better than falling back to English.
        _ => AppLocale.system,
      };
}

/// Persisted language preference. Defaults to [AppLocale.system] until a saved
/// choice loads from [SharedPreferences] — same shape as
/// `theme_style_provider.dart`, including the `mounted` guard after the await.
/// A failing preferences store never throws out of here (#39): a failed read
/// keeps the default, a failed write keeps the in-memory choice.
class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier(
      {Future<SharedPreferences> Function() prefs =
          SharedPreferences.getInstance})
      : _prefs = prefs,
        super(AppLocale.system) {
    _loadPersisted();
  }

  final Future<SharedPreferences> Function() _prefs;

  Future<void> _loadPersisted() async {
    try {
      final prefs = await _prefs();
      if (!mounted) return; // disposed while the read was in flight
      final saved = AppLocale._fromPrefs(prefs.getString(_prefsKey));
      if (saved != state) state = saved;
    } catch (e, st) {
      reportSilently(e, st, where: 'locale.load');
    }
  }

  Future<void> setLocale(AppLocale locale) async {
    if (locale == state) return;
    state = locale;
    try {
      final prefs = await _prefs();
      await prefs.setString(_prefsKey, locale._prefsValue);
    } catch (e, st) {
      reportSilently(e, st, where: 'locale.save');
    }
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, AppLocale>((ref) => LocaleNotifier());

/// The resolved locale for `MaterialApp.router`'s `locale:` — `null` means
/// "follow the system", which is what [WidgetsApp] already does when the field
/// is omitted.
final appLocaleProvider = Provider<Locale?>(
  (ref) => ref.watch(localeProvider).toLocale,
);

/// The saved language as a [Locale] (`null` = follow the phone), read straight
/// from preferences for code that has neither a `ref` nor a `BuildContext` —
/// a notification, say. See `l10n_lookup.dart`.
Future<Locale?> readSavedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return AppLocale._fromPrefs(prefs.getString(_prefsKey)).toLocale;
  } catch (e, st) {
    reportSilently(e, st, where: 'locale.readSaved');
    return null;
  }
}
