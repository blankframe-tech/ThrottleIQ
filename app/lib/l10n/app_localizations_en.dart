// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get riderFallbackName => 'Rider';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get themeCarbonLabel => 'Carbon Mono';

  @override
  String get themeCarbonDescription => 'Dark, sharp, instrument-panel';

  @override
  String get themeEditorialLabel => 'Editorial';

  @override
  String get themeEditorialDescription => 'Light, warm paper';

  @override
  String get appMarkTitle => 'App mark';

  @override
  String get appMarkDarkDescription =>
      'The dark mark, used on the splash and sign-in screens.';

  @override
  String get appMarkLightDescription =>
      'The light mark, used on the splash and sign-in screens.';

  @override
  String get languageSection => 'Language';

  @override
  String get languageSystemLabel => 'System default';

  @override
  String get languageSystemDescription => 'Follow your phone';

  @override
  String get languageEnglishLabel => 'English';

  @override
  String get languageEnglishDescription => 'Always English';

  @override
  String get languageBanglaLabel => 'বাংলা';

  @override
  String get languageBanglaDescription => 'Always Bangla';

  @override
  String get emergencyContactsSection => 'Emergency Contacts';

  @override
  String get emergencyContactsDescription =>
      'Notified if a crash is detected and you don\'t respond within 60 seconds.';

  @override
  String get emergencyContactsEmpty =>
      'No contacts yet — add someone you trust.';

  @override
  String emergencyContactsLoadError(String error) {
    return 'Could not load contacts: $error';
  }

  @override
  String get addAction => 'Add';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get addEmergencyContactTitle => 'Add Emergency Contact';

  @override
  String get contactNameField => 'Name';

  @override
  String get contactPhoneField => 'Phone';

  @override
  String get contactEmailFieldOptional => 'Email (optional)';

  @override
  String get signOutAction => 'Sign Out';
}
