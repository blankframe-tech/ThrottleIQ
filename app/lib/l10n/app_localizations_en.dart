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
  String get skinFieldLabel => 'Skin';

  @override
  String get themeNocturneLabel => 'Nocturne';

  @override
  String get themeNocturneDescription => 'Deep indigo, lavender glow';

  @override
  String get themeTrailSocialLabel => 'Trail Social';

  @override
  String get themeTrailSocialDescription => 'Dark feed, punchy orange';

  @override
  String get themeCalmingLabel => 'Calming';

  @override
  String get themeCalmingDescription => 'Warm cream, soft sage';

  @override
  String get themePositiveVibesLabel => 'Positive Vibes';

  @override
  String get themePositiveVibesDescription => 'Bright white and green';

  @override
  String get themeRetroLabel => 'Retro';

  @override
  String get themeRetroDescription =>
      'Black-and-white terminal, hard square edges';

  @override
  String get themeAnalystBlueLabel => 'Analyst Blue';

  @override
  String get themeAnalystBlueDescription => 'Navy console, cyan telemetry';

  @override
  String get themeGenesisLabel => 'Genesis';

  @override
  String get themeGenesisDescription => 'Near-black, gold and violet';

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

  @override
  String get navSocialLabel => 'Social';

  @override
  String get navRidesLabel => 'Rides';

  @override
  String get navRecordLabel => 'Record';

  @override
  String get navPlacesLabel => 'Places';

  @override
  String get navGarageLabel => 'Garage';

  @override
  String get bikePickerSheetTitle => 'Riding today';

  @override
  String rideCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rides',
      one: '1 ride',
    );
    return '$_temp0';
  }

  @override
  String get changeAction => 'Change';

  @override
  String get ridesStatLabel => 'Rides';

  @override
  String get kilometresStatLabel => 'Kilometres';

  @override
  String get dayStreakStatLabel => 'Day streak';

  @override
  String get rideNotFoundMessage => 'Ride not found';

  @override
  String get niceRideGreeting => 'Nice ride!';

  @override
  String niceRideGreetingNamed(String name) {
    return 'Nice ride, $name!';
  }

  @override
  String get distanceStatLabel => 'km';

  @override
  String get durationStatLabel => 'duration';

  @override
  String get avgSpeedStatLabel => 'avg';

  @override
  String get maxSpeedStatLabel => 'max';

  @override
  String get movingStatLabel => 'moving';

  @override
  String get jamStatLabel => 'in jam';

  @override
  String get scoreSmoothLabel => 'Smooth op.';

  @override
  String get scoreSteadyLabel => 'Steady';

  @override
  String get scoreAggressiveLabel => 'Aggressive';

  @override
  String get ridingScoreLabel => 'Riding score';

  @override
  String get outOf100Label => 'out of 100';

  @override
  String get hardBrakesStatLabel => 'hard brakes';

  @override
  String get rapidAccelStatLabel => 'rapid accel';

  @override
  String get highJerkStatLabel => 'high jerk';

  @override
  String get routeSectionLabel => 'Route';

  @override
  String get saveAndDoneAction => 'Save & done';

  @override
  String get shareAction => 'Share';

  @override
  String get exportJsonAction => 'Export JSON';

  @override
  String get exportGpxAction => 'Export GPX';

  @override
  String get exportFailedMessage => 'Export failed';

  @override
  String get rideExportShareSubject => 'ThrottleIQ ride export';
}
