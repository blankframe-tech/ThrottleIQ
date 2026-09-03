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
  String get vibeFieldLabel => 'Vibe';

  @override
  String get vibeBoxyLabel => 'Boxy';

  @override
  String get vibeBoxyDescription => 'Sharp corners';

  @override
  String get vibeCurvyLabel => 'Curvy';

  @override
  String get vibeCurvyDescription => 'Rounded corners';

  @override
  String get brightnessFieldLabel => 'Brightness';

  @override
  String get brightnessDarkLabel => 'Dark';

  @override
  String get brightnessDarkDescription => 'Dark base';

  @override
  String get brightnessLightLabel => 'Light';

  @override
  String get brightnessLightDescription => 'Light base';

  @override
  String get colorFieldLabel => 'Color';

  @override
  String get themeCarbonLabel => 'Carbon Mono';

  @override
  String get themeCarbonDescription => 'Lime and magenta';

  @override
  String get themeEditorialLabel => 'Editorial';

  @override
  String get themeEditorialDescription => 'Blue and orange, paper warmth';

  @override
  String get themeNocturneLabel => 'Nocturne';

  @override
  String get themeNocturneDescription => 'Indigo and lavender glow';

  @override
  String get themeTrailSocialLabel => 'Trail Social';

  @override
  String get themeTrailSocialDescription => 'Punchy kudos orange';

  @override
  String get themeCalmingLabel => 'Calming';

  @override
  String get themeCalmingDescription => 'Warm sage and tan';

  @override
  String get themeRetroLabel => 'Retro';

  @override
  String get themeRetroDescription => 'Black-and-white terminal, no color';

  @override
  String get themeAnalystBlueLabel => 'Analyst Blue';

  @override
  String get themeAnalystBlueDescription => 'Navy console, cyan telemetry';

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
      'Logged if a crash is detected and you don\'t respond within 60 seconds. Automatic SMS/email alerts aren\'t live yet.';

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
  String get navProfileLabel => 'Profile';

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
  String get speedBandIdleLabel => 'Idle';

  @override
  String get speedBandNormalLabel => 'Normal';

  @override
  String get speedBandBriskLabel => 'Brisk';

  @override
  String get speedBandHardLabel => 'Hard';

  @override
  String get speedOutlierTitle => 'Faster than usual here';

  @override
  String speedOutlierBody(int riderKmh, int baselineKmh) {
    return 'You hit $riderKmh km/h on part of this ride — riders here are usually around $baselineKmh km/h.';
  }

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

  @override
  String get autoTrackingTileTitle => 'Detect rides automatically';

  @override
  String get autoTrackingTileSubtitle =>
      'Logs a ride without you tapping start. Uses about 3–5% battery a day when you are not riding.';

  @override
  String get autoTrackingLocationServicesOffMessage =>
      'Turn on location services to let ThrottleIQ detect rides.';

  @override
  String get autoTrackingPermissionDeniedMessage =>
      'Location permission is required to detect rides.';

  @override
  String get autoTrackingAlwaysPermissionRequiredMessage =>
      'ThrottleIQ needs \"Always\" location access to detect rides while the app is closed. You can change this in Settings.';

  @override
  String get autoTrackingStartFailedMessage =>
      'Could not start background tracking on this device.';

  @override
  String get bikeConfirmationTitle => 'Which bike was this?';

  @override
  String get bikeConfirmationBody =>
      'We detected this ride automatically and logged it to your active bike. Confirm so your service reminders stay accurate.';

  @override
  String get bikeConfirmationUpdatedMessage => 'Ride updated.';

  @override
  String get rideModeSoloLabel => 'Solo';

  @override
  String get rideModeGroupLabel => 'Group';

  @override
  String get rideModeInviteFriendsAction => 'Invite friends';

  @override
  String get rideModeJoinByCodeAction => 'Join with a code';

  @override
  String get joinRideByCodeTitle => 'Join a ride';

  @override
  String get joinRideByCodeSubtitle =>
      'Enter the 6-character code the ride\'s creator shared with you.';

  @override
  String get joinRideCodeHint => 'ABC123';

  @override
  String get joinRideAction => 'Join';

  @override
  String get joinRideCodeInvalidFormat =>
      'That doesn\'t look like a valid code.';

  @override
  String get joinRideGenericError =>
      'Couldn\'t join that ride. Check the code and try again.';

  @override
  String get safeQrTitle => 'SafeQR';

  @override
  String get safeQrSettingsSubtitle =>
      'A scannable medical-info card for first responders';

  @override
  String get safeQrIntro =>
      'Anyone can scan this with a phone camera — no app or account needed on their end. Fill in what you\'d want a first responder or traffic police to know.';

  @override
  String get safeQrEmptyStateHint =>
      'Add your blood group below to generate your card';

  @override
  String get safeQrMedicalInfoSection => 'Medical info';

  @override
  String get safeQrBloodGroupField => 'Blood group';

  @override
  String get safeQrBloodGroupHint => 'e.g. O+';

  @override
  String get safeQrAllergiesField => 'Allergies';

  @override
  String get safeQrConditionsField => 'Medical conditions';

  @override
  String get safeQrMedicationsField => 'Current medications';

  @override
  String safeQrContactIncludedNote(String name) {
    return '$name (your first emergency contact) is included automatically.';
  }

  @override
  String get safeQrNoContactNote =>
      'Add an emergency contact above to include it on this card automatically.';

  @override
  String get safeQrSaveAction => 'Save';

  @override
  String get safeQrSavedMessage => 'SafeQR info saved.';

  @override
  String get safeQrLocalOnlyDisclaimer =>
      'Saved only on this device — it is not backed up or synced.';

  @override
  String get weatherUnavailableTooltip =>
      'Weather data unavailable for this ride';

  @override
  String get weatherUnavailableLabel => 'Weather unavailable';

  @override
  String get overspeedSettingTitle => 'Overspeed Warning Limit';

  @override
  String get overspeedSettingSubtitle =>
      'Haptic and visual alert when exceeding this speed';

  @override
  String get iosAutoTrackingAdvisory =>
      'For uninterrupted ride detection on iOS, keep ThrottleIQ in the background rather than force-closing it from the app switcher.';

  @override
  String get recentDetectionsTitle => 'Auto-Detection History';

  @override
  String get recentDetectionsSubtitle =>
      'Review recent trips recorded or discarded by auto-tracking';

  @override
  String get recentDetectionsEmpty => 'No recent auto-detections logged yet.';

  @override
  String get rejectionTooShort => 'Trip distance was too short';

  @override
  String get rejectionTooSlow => 'Speed was too low to classify as a ride';

  @override
  String get rejectionTooFewFixes => 'Not enough GPS fixes captured';

  @override
  String get rejectionNoMovement => 'No vehicle movement detected';
}
