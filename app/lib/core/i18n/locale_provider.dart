import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.system) {
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // disposed while the read was in flight
    final saved = AppLocale._fromPrefs(prefs.getString(_prefsKey));
    if (saved != state) state = saved;
  }

  Future<void> setLocale(AppLocale locale) async {
    if (locale == state) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale._prefsValue);
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
