import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en')
  ];

  /// AppBar title of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Shown in place of a display name when the account has none set.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get riderFallbackName;

  /// Section header for the theme/appearance controls.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// Name of the dark theme. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Carbon Mono'**
  String get themeCarbonLabel;

  /// One-line description under the Carbon Mono theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark, sharp, instrument-panel'**
  String get themeCarbonDescription;

  /// Name of the light theme. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Editorial'**
  String get themeEditorialLabel;

  /// One-line description under the Editorial theme option.
  ///
  /// In en, this message translates to:
  /// **'Light, warm paper'**
  String get themeEditorialDescription;

  /// Label above the dropdown that picks the app's visual skin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get skinFieldLabel;

  /// Name of the Nocturne skin. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Nocturne'**
  String get themeNocturneLabel;

  /// One-line description under the Nocturne skin option.
  ///
  /// In en, this message translates to:
  /// **'Deep indigo, lavender glow'**
  String get themeNocturneDescription;

  /// Name of the Trail Social skin. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Trail Social'**
  String get themeTrailSocialLabel;

  /// One-line description under the Trail Social skin option.
  ///
  /// In en, this message translates to:
  /// **'Dark feed, punchy orange'**
  String get themeTrailSocialDescription;

  /// Name of the Calming skin. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Calming'**
  String get themeCalmingLabel;

  /// One-line description under the Calming skin option.
  ///
  /// In en, this message translates to:
  /// **'Warm cream, soft sage'**
  String get themeCalmingDescription;

  /// Name of the Positive Vibes skin. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Positive Vibes'**
  String get themePositiveVibesLabel;

  /// One-line description under the Positive Vibes skin option.
  ///
  /// In en, this message translates to:
  /// **'Bright white and green'**
  String get themePositiveVibesDescription;

  /// Name of the Retro skin. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Retro'**
  String get themeRetroLabel;

  /// One-line description under the Retro skin option.
  ///
  /// In en, this message translates to:
  /// **'Black-and-white terminal, hard square edges'**
  String get themeRetroDescription;

  /// Name of the Analyst Blue skin. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Analyst Blue'**
  String get themeAnalystBlueLabel;

  /// One-line description under the Analyst Blue skin option.
  ///
  /// In en, this message translates to:
  /// **'Navy console, cyan telemetry'**
  String get themeAnalystBlueDescription;

  /// Name of the Genesis skin. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Genesis'**
  String get themeGenesisLabel;

  /// One-line description under the Genesis skin option.
  ///
  /// In en, this message translates to:
  /// **'Near-black, gold and violet'**
  String get themeGenesisDescription;

  /// Label beside the live logo preview in the Appearance section.
  ///
  /// In en, this message translates to:
  /// **'App mark'**
  String get appMarkTitle;

  /// Description of the logo preview while the dark theme is selected.
  ///
  /// In en, this message translates to:
  /// **'The dark mark, used on the splash and sign-in screens.'**
  String get appMarkDarkDescription;

  /// Description of the logo preview while the light theme is selected.
  ///
  /// In en, this message translates to:
  /// **'The light mark, used on the splash and sign-in screens.'**
  String get appMarkLightDescription;

  /// Section header for the app language control.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// Language option that follows the phone's own language setting.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemLabel;

  /// One-line description under the system-default language option.
  ///
  /// In en, this message translates to:
  /// **'Follow your phone'**
  String get languageSystemDescription;

  /// The English language option. Language names are always written in their own language, so this is NOT translated.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishLabel;

  /// One-line description under the English language option.
  ///
  /// In en, this message translates to:
  /// **'Always English'**
  String get languageEnglishDescription;

  /// The Bangla language option. Language names are always written in their own language, so this stays in Bangla even in the English ARB.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get languageBanglaLabel;

  /// One-line description under the Bangla language option.
  ///
  /// In en, this message translates to:
  /// **'Always Bangla'**
  String get languageBanglaDescription;

  /// Section header for the emergency contact list.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get emergencyContactsSection;

  /// Explains when emergency contacts get alerted. The 60 stays a Western numeral in every language — see core/i18n/numeric_locale.dart.
  ///
  /// In en, this message translates to:
  /// **'Notified if a crash is detected and you don\'t respond within 60 seconds.'**
  String get emergencyContactsDescription;

  /// Empty state for the emergency contact list.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet — add someone you trust.'**
  String get emergencyContactsEmpty;

  /// Shown when the emergency contact list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load contacts: {error}'**
  String emergencyContactsLoadError(String error);

  /// Button that opens the add-emergency-contact dialog, and the confirm button inside it.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// Dismisses the add-emergency-contact dialog without saving.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Title of the add-emergency-contact dialog.
  ///
  /// In en, this message translates to:
  /// **'Add Emergency Contact'**
  String get addEmergencyContactTitle;

  /// Label for the contact name text field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactNameField;

  /// Label for the contact phone text field.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactPhoneField;

  /// Label for the optional contact email text field.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get contactEmailFieldOptional;

  /// Button that signs the rider out and returns to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutAction;

  /// Bottom-nav tab label for the social/feed tab.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get navSocialLabel;

  /// Bottom-nav tab label for the rides/stats tab.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get navRidesLabel;

  /// Bottom-nav tab label for the record-a-ride tab.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get navRecordLabel;

  /// Bottom-nav tab label for the places/POI-directory tab.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get navPlacesLabel;

  /// Bottom-nav tab label for the garage/bikes tab.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get navGarageLabel;

  /// Title of the bottom sheet that lets the rider switch which bike is active, on the Record screen.
  ///
  /// In en, this message translates to:
  /// **'Riding today'**
  String get bikePickerSheetTitle;

  /// How many times a bike has been ridden, shown as the subtitle under its name in the bike-switcher sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ride} other{{count} rides}}'**
  String rideCountLabel(int count);

  /// Affordance on the Record-screen hero that opens the bike switcher. Rendered upper-case in the UI.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeAction;

  /// Label under the rider's total ride count, in the Record screen's stat strip.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get ridesStatLabel;

  /// Label under the rider's total distance, in the Record screen's stat strip.
  ///
  /// In en, this message translates to:
  /// **'Kilometres'**
  String get kilometresStatLabel;

  /// Label under the rider's current consecutive-day riding streak, in the Record screen's stat strip.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get dayStreakStatLabel;

  /// Shown on the ride summary screen when the ride id it was given doesn't resolve to a ride.
  ///
  /// In en, this message translates to:
  /// **'Ride not found'**
  String get rideNotFoundMessage;

  /// Header on the ride summary screen when the rider's display name isn't available.
  ///
  /// In en, this message translates to:
  /// **'Nice ride!'**
  String get niceRideGreeting;

  /// Header on the ride summary screen, with the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Nice ride, {name}!'**
  String niceRideGreetingNamed(String name);

  /// Unit label under the distance figure on the ride summary screen's stat row.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get distanceStatLabel;

  /// Label under the ride's total duration on the ride summary screen's stat row.
  ///
  /// In en, this message translates to:
  /// **'duration'**
  String get durationStatLabel;

  /// Label under the average-speed figure on the ride summary screen's stat row.
  ///
  /// In en, this message translates to:
  /// **'avg'**
  String get avgSpeedStatLabel;

  /// Label under the top-speed figure on the ride summary screen's stat row.
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get maxSpeedStatLabel;

  /// Label under the moving-time figure on the ride summary screen's jam-time card.
  ///
  /// In en, this message translates to:
  /// **'moving'**
  String get movingStatLabel;

  /// Label under the stopped-in-traffic time figure on the ride summary screen's jam-time card.
  ///
  /// In en, this message translates to:
  /// **'in jam'**
  String get jamStatLabel;

  /// Riding-score rating for a high score (80+) on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Smooth op.'**
  String get scoreSmoothLabel;

  /// Riding-score rating for a mid score (60-79) on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get scoreSteadyLabel;

  /// Riding-score rating for a low score (below 60) on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get scoreAggressiveLabel;

  /// Label on the riding-score card on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Riding score'**
  String get ridingScoreLabel;

  /// Sits under the riding-score rating word, clarifying the score's scale. The 100 stays a Western numeral in every language — see core/i18n/numeric_locale.dart.
  ///
  /// In en, this message translates to:
  /// **'out of 100'**
  String get outOf100Label;

  /// Label under the hard-brake event count on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'hard brakes'**
  String get hardBrakesStatLabel;

  /// Label under the rapid-acceleration event count on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'rapid accel'**
  String get rapidAccelStatLabel;

  /// Label under the high-jerk (sudden jolt) event count on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'high jerk'**
  String get highJerkStatLabel;

  /// Section header above the route map on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeSectionLabel;

  /// Primary button on the ride summary screen — dismisses the screen, keeping the ride.
  ///
  /// In en, this message translates to:
  /// **'Save & done'**
  String get saveAndDoneAction;

  /// Button that opens the ride-share flow from the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// Button that exports the ride as a JSON file. JSON is a file-format name and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJsonAction;

  /// Button that exports the ride as a GPX file. GPX is a file-format name and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get exportGpxAction;

  /// Snackbar shown when a JSON/GPX ride export fails.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailedMessage;

  /// Subject line of the share-sheet action used to send an exported ride file. ThrottleIQ is the product name and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ ride export'**
  String get rideExportShareSubject;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
