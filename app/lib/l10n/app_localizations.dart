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

  /// Label above the Boxy/Curvy shape selector.
  ///
  /// In en, this message translates to:
  /// **'Vibe'**
  String get vibeFieldLabel;

  /// Name of the sharp-cornered shape vibe.
  ///
  /// In en, this message translates to:
  /// **'Boxy'**
  String get vibeBoxyLabel;

  /// One-line description under the Boxy vibe option.
  ///
  /// In en, this message translates to:
  /// **'Sharp corners'**
  String get vibeBoxyDescription;

  /// Name of the rounded-corner shape vibe.
  ///
  /// In en, this message translates to:
  /// **'Curvy'**
  String get vibeCurvyLabel;

  /// One-line description under the Curvy vibe option.
  ///
  /// In en, this message translates to:
  /// **'Rounded corners'**
  String get vibeCurvyDescription;

  /// Label above the Dark/Light brightness selector.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightnessFieldLabel;

  /// Name of the dark brightness option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get brightnessDarkLabel;

  /// One-line description under the Dark brightness option.
  ///
  /// In en, this message translates to:
  /// **'Dark base'**
  String get brightnessDarkDescription;

  /// Name of the light brightness option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get brightnessLightLabel;

  /// One-line description under the Light brightness option.
  ///
  /// In en, this message translates to:
  /// **'Light base'**
  String get brightnessLightDescription;

  /// Appearance option that follows the OS light/dark setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get brightnessSystemLabel;

  /// Sub-label under the System brightness option.
  ///
  /// In en, this message translates to:
  /// **'Match your phone'**
  String get brightnessSystemDescription;

  /// Label above the dropdown that picks the app's color mode.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorFieldLabel;

  /// Name of the Carbon Mono color mode. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Carbon Mono'**
  String get themeCarbonLabel;

  /// One-line description under the Carbon Mono color option.
  ///
  /// In en, this message translates to:
  /// **'Lime and magenta'**
  String get themeCarbonDescription;

  /// Name of the Editorial color mode. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Editorial'**
  String get themeEditorialLabel;

  /// One-line description under the Editorial color option.
  ///
  /// In en, this message translates to:
  /// **'Blue and orange, paper warmth'**
  String get themeEditorialDescription;

  /// Name of the Nocturne color mode. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Nocturne'**
  String get themeNocturneLabel;

  /// One-line description under the Nocturne color option.
  ///
  /// In en, this message translates to:
  /// **'Indigo and lavender glow'**
  String get themeNocturneDescription;

  /// Name of the Trail Social color mode. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Trail Social'**
  String get themeTrailSocialLabel;

  /// One-line description under the Trail Social color option.
  ///
  /// In en, this message translates to:
  /// **'Punchy kudos orange'**
  String get themeTrailSocialDescription;

  /// Name of the Calming color mode. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Calming'**
  String get themeCalmingLabel;

  /// One-line description under the Calming color option.
  ///
  /// In en, this message translates to:
  /// **'Warm sage and tan'**
  String get themeCalmingDescription;

  /// Name of the Retro color mode. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Retro'**
  String get themeRetroLabel;

  /// One-line description under the Retro color option.
  ///
  /// In en, this message translates to:
  /// **'Blocky 70s poster, mustard & rust'**
  String get themeRetroDescription;

  /// Name of the Analyst Blue color mode. Product name — kept recognisable across languages.
  ///
  /// In en, this message translates to:
  /// **'Analyst Blue'**
  String get themeAnalystBlueLabel;

  /// One-line description under the Analyst Blue color option.
  ///
  /// In en, this message translates to:
  /// **'Navy console, cyan telemetry'**
  String get themeAnalystBlueDescription;

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

  /// Explains when emergency contacts get alerted, and is honest that delivery isn't implemented yet — issues §24.8: the crash-alert Cloud Function (crash-notifications.ts) only ever logs a mock send, it never actually contacts anyone, and this copy previously claimed contacts ARE notified. The 60 stays a Western numeral in every language — see core/i18n/numeric_locale.dart.
  ///
  /// In en, this message translates to:
  /// **'Logged if a crash is detected and you don\'t respond within 60 seconds. Automatic SMS/email alerts aren\'t live yet.'**
  String get emergencyContactsDescription;

  /// Warning-colored banner above the emergency contact list. Must stay unmissable until crash alerts actually send (grill §3.6.3) — adding a contact must not read as being protected.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ does not yet alert these contacts automatically.'**
  String get emergencyContactsNotAlertedBanner;

  /// Title of the one-time acknowledgement dialog shown after the rider adds their first emergency contact.
  ///
  /// In en, this message translates to:
  /// **'Contacts aren\'t alerted yet'**
  String get emergencyContactsAckTitle;

  /// Body of the one-time emergency-contact acknowledgement dialog.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ saved this contact, but it can\'t send them an SMS or email after a crash yet. Until it can, tell someone your route before you ride.'**
  String get emergencyContactsAckBody;

  /// Dismisses the one-time emergency-contact acknowledgement dialog.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get emergencyContactsAckAction;

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

  /// Bottom-nav tab label for the profile tab (profile, settings, notifications, bikes/garage).
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfileLabel;

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

  /// Legend label for the slowest speed band on the ride summary map's speed-colored route (under 5 km/h).
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get speedBandIdleLabel;

  /// Legend label for the normal speed band on the ride summary map's speed-colored route (5-50 km/h).
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get speedBandNormalLabel;

  /// Legend label for the brisk speed band on the ride summary map's speed-colored route (50-90 km/h).
  ///
  /// In en, this message translates to:
  /// **'Brisk'**
  String get speedBandBriskLabel;

  /// Legend label for the fastest speed band on the ride summary map's speed-colored route (90 km/h and up).
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get speedBandHardLabel;

  /// Title of the private post-ride card shown when part of this ride was a statistical outlier against the anonymous road-speed baseline for that stretch. Never shown to anyone but the rider themselves.
  ///
  /// In en, this message translates to:
  /// **'Faster than usual here'**
  String get speedOutlierTitle;

  /// Body of the speed-outlier card. {riderKmh} and {baselineKmh} are both whole-number km/h, always Western digits regardless of language — see core/i18n/numeric_locale.dart.
  ///
  /// In en, this message translates to:
  /// **'You hit {riderKmh} km/h on part of this ride — riders here are usually around {baselineKmh} km/h.'**
  String speedOutlierBody(int riderKmh, int baselineKmh);

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

  /// Button that exports the ride's full per-point telemetry as a CSV file. CSV is a file-format name and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsvAction;

  /// Snackbar shown when a JSON/GPX/CSV ride export fails.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailedMessage;

  /// Section header above the JSON/GPX/CSV export buttons on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Telemetry'**
  String get telemetrySectionLabel;

  /// Label on the ride summary screen's speed card, showing average speed over moving time in km/h. Key kept from when this card showed a runner's min/km pace.
  ///
  /// In en, this message translates to:
  /// **'Avg moving speed'**
  String get ridingPaceLabel;

  /// Label for the moving-time vs stopped-time line on the ride summary's speed card, e.g. '42m / 8m'.
  ///
  /// In en, this message translates to:
  /// **'Moving / stopped'**
  String get movingStoppedLabel;

  /// Header of the card showing GPS track-point count and start/end coordinates on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Route GPS Details'**
  String get routeGpsDetailsLabel;

  /// Count of raw GPS track points recorded for a ride, shown on the Route GPS Details card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track point} other{{count} track points}}'**
  String trackPointsCountLabel(int count);

  /// Label before the ride's starting coordinates on the Route GPS Details card.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startPointLabel;

  /// Label before the ride's ending coordinates on the Route GPS Details card.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishPointLabel;

  /// Button that opens the full-screen interactive route map from the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Explore Full Route on Map'**
  String get exploreFullRouteAction;

  /// Map action button/tooltip that opens the save-route screen for this ride.
  ///
  /// In en, this message translates to:
  /// **'Save as Route'**
  String get saveAsRouteAction;

  /// Hint pill overlaid on the ride summary screen's route map, inviting a tap to open the full-screen map.
  ///
  /// In en, this message translates to:
  /// **'Tap map to expand'**
  String get mapExpandHintLabel;

  /// Label for the ride's estimated total climb, on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Elevation Gain'**
  String get elevationGainLabel;

  /// Label for the ride's estimated total descent, on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Elevation Loss'**
  String get elevationLossLabel;

  /// Header above the ride's altitude-over-route mini chart on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Elevation Profile'**
  String get elevationProfileLabel;

  /// Header above the ride's speed-over-route mini chart on the ride summary screen.
  ///
  /// In en, this message translates to:
  /// **'Speed Profile'**
  String get speedProfileLabel;

  /// Subject line of the share-sheet action used to send an exported ride file. ThrottleIQ is the product name and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ ride export'**
  String get rideExportShareSubject;

  /// Title of the settings switch that turns on background ride detection.
  ///
  /// In en, this message translates to:
  /// **'Detect rides automatically'**
  String get autoTrackingTileTitle;

  /// Subtitle under the auto-tracking switch, naming the battery cost so the ask reads as honest rather than evasive.
  ///
  /// In en, this message translates to:
  /// **'Logs a ride without you tapping start. Uses about 3–5% battery a day when you are not riding.'**
  String get autoTrackingTileSubtitle;

  /// Snackbar shown when the rider enables auto-tracking but the device's location services are off.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to let ThrottleIQ detect rides.'**
  String get autoTrackingLocationServicesOffMessage;

  /// Snackbar shown when the rider denies the location permission auto-tracking needs.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to detect rides.'**
  String get autoTrackingPermissionDeniedMessage;

  /// Snackbar shown when the rider grants only "while in use" location access instead of "Always".
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ needs \"Always\" location access to detect rides while the app is closed. You can change this in Settings.'**
  String get autoTrackingAlwaysPermissionRequiredMessage;

  /// Snackbar shown when the background tracking plugin fails to start despite permissions being granted.
  ///
  /// In en, this message translates to:
  /// **'Could not start background tracking on this device.'**
  String get autoTrackingStartFailedMessage;

  /// Heading on the card asking the rider to confirm which bike an auto-detected ride was on.
  ///
  /// In en, this message translates to:
  /// **'Which bike was this?'**
  String get bikeConfirmationTitle;

  /// Explanatory body text under the bike-confirmation card heading.
  ///
  /// In en, this message translates to:
  /// **'We detected this ride automatically and logged it to your active bike. Confirm so your service reminders stay accurate.'**
  String get bikeConfirmationBody;

  /// Snackbar shown after the rider confirms or corrects which bike an auto-detected ride was on.
  ///
  /// In en, this message translates to:
  /// **'Ride updated.'**
  String get bikeConfirmationUpdatedMessage;

  /// Row on the ride summary screen (most recent ride only) showing which bike the ride was logged to, next to a Change action.
  ///
  /// In en, this message translates to:
  /// **'Logged to {bikeName}'**
  String loggedToBikeLabel(String bikeName);

  /// Title of the bottom sheet that picks a different bike for the most recent completed ride.
  ///
  /// In en, this message translates to:
  /// **'Change bike'**
  String get changeBikeSheetTitle;

  /// Segment label for riding alone, in the Solo/Group choice on the Record screen.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get rideModeSoloLabel;

  /// Segment label for riding with others, in the Solo/Group choice on the Record screen.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get rideModeGroupLabel;

  /// Button that opens the friend picker to start a group ride by inviting riders.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get rideModeInviteFriendsAction;

  /// Button that opens the join-by-code sheet for a group ride someone else started.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get rideModeJoinByCodeAction;

  /// Title of the sheet where a rider types in a group ride's join code.
  ///
  /// In en, this message translates to:
  /// **'Join a ride'**
  String get joinRideByCodeTitle;

  /// Subtitle explaining what to type into the join-code sheet.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-character code the ride\'s creator shared with you.'**
  String get joinRideByCodeSubtitle;

  /// Placeholder text in the join-code input field, shaped like a real code.
  ///
  /// In en, this message translates to:
  /// **'ABC123'**
  String get joinRideCodeHint;

  /// Button that submits the typed join code.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinRideAction;

  /// Shown when the typed text is the wrong shape to even be a join code.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a valid code.'**
  String get joinRideCodeInvalidFormat;

  /// Fallback error shown when joining by code fails for an unrecognized reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join that ride. Check the code and try again.'**
  String get joinRideGenericError;

  /// Title of the SafeQR screen and its entry point in Settings.
  ///
  /// In en, this message translates to:
  /// **'SafeQR'**
  String get safeQrTitle;

  /// Subtitle under the SafeQR tile in Settings.
  ///
  /// In en, this message translates to:
  /// **'A scannable medical-info card for first responders'**
  String get safeQrSettingsSubtitle;

  /// Explanatory text at the top of the SafeQR screen.
  ///
  /// In en, this message translates to:
  /// **'Anyone can scan this with a phone camera — no app or account needed on their end. Fill in what you\'d want a first responder or traffic police to know.'**
  String get safeQrIntro;

  /// Shown in place of the QR code before the rider has entered anything worth scanning.
  ///
  /// In en, this message translates to:
  /// **'Add your blood group below to generate your card'**
  String get safeQrEmptyStateHint;

  /// Section heading above the SafeQR editable fields.
  ///
  /// In en, this message translates to:
  /// **'Medical info'**
  String get safeQrMedicalInfoSection;

  /// Label for the blood group input field.
  ///
  /// In en, this message translates to:
  /// **'Blood group'**
  String get safeQrBloodGroupField;

  /// Placeholder text in the blood group input field.
  ///
  /// In en, this message translates to:
  /// **'e.g. O+'**
  String get safeQrBloodGroupHint;

  /// Label for the allergies input field.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get safeQrAllergiesField;

  /// Label for the medical conditions input field.
  ///
  /// In en, this message translates to:
  /// **'Medical conditions'**
  String get safeQrConditionsField;

  /// Label for the current medications input field.
  ///
  /// In en, this message translates to:
  /// **'Current medications'**
  String get safeQrMedicationsField;

  /// Note explaining that an emergency contact is pulled in automatically, naming which one.
  ///
  /// In en, this message translates to:
  /// **'{name} (your first emergency contact) is included automatically.'**
  String safeQrContactIncludedNote(String name);

  /// Note shown when the rider has no emergency contact yet to pull onto the card.
  ///
  /// In en, this message translates to:
  /// **'Add an emergency contact above to include it on this card automatically.'**
  String get safeQrNoContactNote;

  /// Button that saves the SafeQR medical info fields.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get safeQrSaveAction;

  /// Snackbar shown after saving SafeQR medical info.
  ///
  /// In en, this message translates to:
  /// **'SafeQR info saved.'**
  String get safeQrSavedMessage;

  /// Disclaimer clarifying that SafeQR medical info is device-local, not cloud-synced.
  ///
  /// In en, this message translates to:
  /// **'Saved only on this device — it is not backed up or synced.'**
  String get safeQrLocalOnlyDisclaimer;

  /// Button that exports the SafeQR card as a PNG through the system share sheet (which also offers Save to Photos/Files), e.g. to set as a lock-screen wallpaper or print as a helmet sticker.
  ///
  /// In en, this message translates to:
  /// **'Save or share QR image'**
  String get safeQrShareImageAction;

  /// Snackbar shown when rendering the SafeQR card to an image fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the QR image.'**
  String get safeQrShareImageFailed;

  /// Tooltip shown on the weather badge when weather could not be retrieved.
  ///
  /// In en, this message translates to:
  /// **'Weather data unavailable for this ride'**
  String get weatherUnavailableTooltip;

  /// Label shown when weather information could not be retrieved.
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable'**
  String get weatherUnavailableLabel;

  /// Title for the overspeed limit slider in settings.
  ///
  /// In en, this message translates to:
  /// **'Overspeed Warning Limit'**
  String get overspeedSettingTitle;

  /// Subtitle explaining the overspeed alert.
  ///
  /// In en, this message translates to:
  /// **'Haptic and visual alert when exceeding this speed'**
  String get overspeedSettingSubtitle;

  /// Advisory note for iOS users about app lifecycle constraint.
  ///
  /// In en, this message translates to:
  /// **'For uninterrupted ride detection on iOS, keep ThrottleIQ in the background rather than force-closing it from the app switcher.'**
  String get iosAutoTrackingAdvisory;

  /// Title for auto-detection history sheet.
  ///
  /// In en, this message translates to:
  /// **'Auto-Detection History'**
  String get recentDetectionsTitle;

  /// Subtitle for auto-detection history sheet.
  ///
  /// In en, this message translates to:
  /// **'Review recent trips recorded or discarded by auto-tracking'**
  String get recentDetectionsSubtitle;

  /// Empty state text for auto-detection history.
  ///
  /// In en, this message translates to:
  /// **'No recent auto-detections logged yet.'**
  String get recentDetectionsEmpty;

  /// Humanized rejection reason for too short distance.
  ///
  /// In en, this message translates to:
  /// **'Trip distance was too short'**
  String get rejectionTooShort;

  /// Humanized rejection reason for too low speed.
  ///
  /// In en, this message translates to:
  /// **'Speed was too low to classify as a ride'**
  String get rejectionTooSlow;

  /// Humanized rejection reason for insufficient GPS fixes.
  ///
  /// In en, this message translates to:
  /// **'Not enough GPS fixes captured'**
  String get rejectionTooFewFixes;

  /// Humanized rejection reason for lack of movement.
  ///
  /// In en, this message translates to:
  /// **'No vehicle movement detected'**
  String get rejectionNoMovement;

  /// Cockpit alert shown when the rider brakes hard.
  ///
  /// In en, this message translates to:
  /// **'Ease on the brakes'**
  String get rideAlertHardBraking;

  /// Cockpit alert shown on rapid acceleration.
  ///
  /// In en, this message translates to:
  /// **'Smooth on the throttle'**
  String get rideAlertRapidAccel;

  /// Cockpit alert shown when the rider exceeds their speed limit.
  ///
  /// In en, this message translates to:
  /// **'Watch your speed'**
  String get rideAlertOverspeed;

  /// Cockpit alert shown after 90 minutes of riding.
  ///
  /// In en, this message translates to:
  /// **'Time for a break'**
  String get rideAlertFatigue;

  /// Action in the live-location sheet that re-sends the share link.
  ///
  /// In en, this message translates to:
  /// **'Share link again'**
  String get liveShareAgainAction;

  /// Action in the live-location sheet that revokes the share link.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing now'**
  String get liveShareStopAction;

  /// Sub-label under 'Stop sharing now'.
  ///
  /// In en, this message translates to:
  /// **'The link stops working. Your ride keeps recording.'**
  String get liveShareStopDescription;

  /// Label in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Email required'**
  String get emailRequired;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// Label in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Tooltip in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get passwordTooShort;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccountPrompt;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Text in login_screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue tracking your rides'**
  String get signInSubtitle;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Your Garage'**
  String get yourGarage;

  /// Subtitle in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Every bike you own, tracked in one place.'**
  String get everyBikeOwnTracked;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Add unlimited bikes — brand, model, year, CC'**
  String get addUnlimitedBikesBrand;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Your bike\'s paint color tints the whole app'**
  String get bikesPaintColorTints;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Tap any bike to view full history & details'**
  String get tapAnyBikeView;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Switch active bike before each ride'**
  String get switchActiveBikeBefore;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Active Motorcycle'**
  String get activeMotorcycle;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Tints the entire app theme and binds to your trip logs.'**
  String get tintsEntireAppTheme;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Service Countdown'**
  String get serviceCountdown;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Real-time maintenance tracker based on actual km ridden.'**
  String get realTimeMaintenanceTracker;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Add & Switch'**
  String get addSwitch;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Manage multiple bikes and swap your active ride anytime.'**
  String get manageMultipleBikesSwap;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Start a Ride'**
  String get startRide;

  /// Subtitle in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Hold the button. ThrottleIQ does the rest.'**
  String get holdButtonThrottleiqDoes;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Hold-to-start on the Record tab to begin'**
  String get holdStartRecordTab;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'GPS + sensor fusion captures every moment'**
  String get gpsSensorFusionCaptures;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Continues recording in the background'**
  String get continuesRecordingBackground;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'A paused ride survives the app being closed'**
  String get pausedRideSurvivesApp;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Share your live location with family in real time'**
  String get shareLiveLocationWith;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Cockpit Telemetry'**
  String get cockpitTelemetry;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Live GPS speed, distance, and ride telemetry as you go.'**
  String get liveGpsSpeedDistance;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Hold 1s to Record'**
  String get hold1sRecord;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Hold 1s to start or stop; prevents accidental touches.'**
  String get hold1sStartStop;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Live Share'**
  String get liveShare;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Send a revocable link so family can follow your ride.'**
  String get sendRevocableLinkSo;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Auto Tracking'**
  String get autoTracking;

  /// Subtitle in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Rides that detect and record themselves.'**
  String get ridesThatDetectRecord;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Enable once in Settings → Auto-Tracking'**
  String get enableOnceSettingsAuto;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Activity recognition starts recording when you ride'**
  String get activityRecognitionStartsRecording;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Short walks and subway trips are filtered out'**
  String get shortWalksSubwayTrips;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Each auto-detected ride appears ready to review'**
  String get eachAutoDetectedRide;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Smart Detection'**
  String get smartDetection;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Detects motorcycle movement via IMU sensors & speed.'**
  String get detectsMotorcycleMovementVia;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Non-Ride Filter'**
  String get nonRideFilter;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Ignores walking, bus rides, and minor phone jostling.'**
  String get ignoresWalkingBusRides;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Zero Interaction'**
  String get zeroInteraction;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Runs silently in background; review rides when done.'**
  String get runsSilentlyBackgroundReview;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// Subtitle in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Never forget another oil change.'**
  String get neverForgetAnotherOil;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Alerts when you\'re due for oil, filter, chain lube…'**
  String get alertsWhenYoureDue;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Log a service to reset the countdown'**
  String get logServiceResetCountdown;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Add custom intervals for any part you care about'**
  String get addCustomIntervalsAny;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'13+ Service Items'**
  String get n13ServiceItems;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Track engine oil, chain lube, brake fluid, coolant, and more.'**
  String get trackEngineOilChain;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Due Badges'**
  String get dueBadges;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Color-coded progress bars alert you before intervals expire.'**
  String get colorCodedProgressBars;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Log & Reset'**
  String get logReset;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Record maintenance notes and reset the interval odometer.'**
  String get recordMaintenanceNotesReset;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Rider Places'**
  String get riderPlaces;

  /// Subtitle in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Every garage, pump, and viewpoint near you.'**
  String get everyGaragePumpViewpoint;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Fuel stations, repair shops, spare parts & cafes'**
  String get fuelStationsRepairShops;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Tap Directions → opens Maps, and offers to record'**
  String get tapDirectionsOpensMaps;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Add and rate places to help the community'**
  String get addRatePlacesHelp;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'395+ Rider POIs'**
  String get n395RiderPois;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Verified fuel stations, workshops, parts, and rider cafes.'**
  String get verifiedFuelStationsWorkshops;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Navigate & Record'**
  String get navigateRecord;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Opens your maps app, and can record the trip alongside it.'**
  String get opensMapsAppCan;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Rider Reviews'**
  String get riderReviews;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Rate octane purity, mechanic honesty, and parking security.'**
  String get rateOctanePurityMechanic;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Ride Together'**
  String get rideTogether;

  /// Subtitle in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Your riding community, all in one place.'**
  String get ridingCommunityAllOne;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Share rides to the feed — home location is hidden'**
  String get shareRidesFeedHome;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Start a group ride with a 6-character join code'**
  String get startGroupRideWith;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Push-to-talk intercom for your Bluetooth helmet'**
  String get pushTalkIntercomBluetooth;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Bike-model forums — talk to FZ-S, Pulsar & CBR riders'**
  String get bikeModelForumsTalk;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Direct message any rider on the platform'**
  String get directMessageAnyRider;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Privacy Zones'**
  String get privacyZones;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Each ride\'s start and end are clipped before it is shared.'**
  String get eachRidesStartEnd;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Group PIN & Intercom'**
  String get groupPinIntercom;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Live map tracking and Bluetooth helmet PTT intercom.'**
  String get liveMapTrackingBluetooth;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Bike Model Forums'**
  String get bikeModelForums;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Discuss mods, issues, and meets with owners of your bike.'**
  String get discussModsIssuesMeets;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get yourProfile;

  /// Subtitle in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Make it yours — add a bio to stand out.'**
  String get makeItYoursAdd;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Public profile with your stats & shared rides'**
  String get publicProfileWithStats;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Your @handle lets other riders find and follow you'**
  String get handleLetsOtherRiders;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Control who sees your profile and your bikes'**
  String get controlWhoSeesProfile;

  /// Text in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'SafeQR: an offline emergency medical card'**
  String get safeqrOfflineEmergencyMedical;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Rider Stats'**
  String get riderStats;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Showcase total km, safety score, and peak achievements.'**
  String get showcaseTotalKmSafety;

  /// Title in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'SafeQR Card'**
  String get safeqrCard;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Offline medical card for emergency responders on the road.'**
  String get offlineMedicalCardEmergency;

  /// Description in onboarding_manifest.
  ///
  /// In en, this message translates to:
  /// **'Keep up to 5 contacts on file for a responder to reach.'**
  String get keepUp5Contacts;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'That username is taken — try another.'**
  String get thatUsernameTakenTry;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Error: {e}'**
  String errorWithDetail(Object e);

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get whatShouldWeCall;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Add your first bike'**
  String get addFirstBike;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Your name and @handle so the community can find you.'**
  String get nameHandleSoCommunity;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ tracks rides and maintenance per bike.'**
  String get throttleiqTracksRidesMaintenance;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Continue →'**
  String get continueAction;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Add bike & take the tour'**
  String get addBikeTakeTour;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get backArrow;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipNow;

  /// LabelText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get fullName;

  /// HintText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rahim Hossain'**
  String get eGRahimHossain;

  /// Validator in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// LabelText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Username *'**
  String get username;

  /// HelperText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, underscore · 3–20 chars'**
  String get lettersNumbersUnderscore3;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'3-20 characters: letters, numbers, underscore'**
  String get n320CharactersLetters;

  /// LabelText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Brand *'**
  String get brand;

  /// LabelText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Model *'**
  String get model;

  /// LabelText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// LabelText in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Engine CC'**
  String get engineCc;

  /// Tooltip in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Exit demo'**
  String get exitDemo;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Your Info'**
  String get yourInfo;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Your Bike'**
  String get yourBike;

  /// Text in onboarding_screen.
  ///
  /// In en, this message translates to:
  /// **'Feature Tour'**
  String get featureTour;

  /// Text in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Tooltip in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Text in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Join ThrottleIQ'**
  String get joinThrottleiq;

  /// Text in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Track every ride, remember every mile'**
  String get trackEveryRideRemember;

  /// HintText in register_screen.
  ///
  /// In en, this message translates to:
  /// **'6+ characters'**
  String get n6Characters;

  /// Text in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get min6Characters;

  /// LabelText in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Text in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Text in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get signUpWithGoogle;

  /// Text in register_screen.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// Text in splash_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride smarter. Track deeper.'**
  String get rideSmarterTrackDeeper;

  /// Text in onboarding_slide_page.
  ///
  /// In en, this message translates to:
  /// **'GUIDE {slideIndex} OF {totalSlides}'**
  String guideProgress(Object slideIndex, Object totalSlides);

  /// Text in onboarding_slide_page.
  ///
  /// In en, this message translates to:
  /// **'Skip tour'**
  String get skipTour;

  /// Text in onboarding_slide_page.
  ///
  /// In en, this message translates to:
  /// **'Show me'**
  String get showMe;

  /// Text in onboarding_slide_page.
  ///
  /// In en, this message translates to:
  /// **'Get Riding 🏍️'**
  String get getRiding;

  /// Text in onboarding_slide_page.
  ///
  /// In en, this message translates to:
  /// **'Got it  →'**
  String get gotIt;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'My Garage'**
  String get myGarage;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Add Bike'**
  String get addBike;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get active;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'4,280 km logged'**
  String get n4280KmLogged;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Oil & Filter Due in 720 km'**
  String get oilFilterDue720;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Theme Tint:'**
  String get themeTint;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'GPS LOCKED'**
  String get gpsLocked;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'AVG 52 · '**
  String get avg52;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'TOP 124'**
  String get top124;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'DISTANCE'**
  String get distance;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'MOVING 31m'**
  String get moving31m;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'HOLD 1s TO START'**
  String get hold1sStart;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Auto-Tracking Settings'**
  String get autoTrackingSettings;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Smart Non-Ride Filter Active'**
  String get smartNonRideFilter;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Walking, buses & subway rides automatically ignored'**
  String get walkingBusesSubwayRides;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Detected Ride'**
  String get detectedRide;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'AUTO SAVED'**
  String get autoSaved;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Schedule'**
  String get maintenanceSchedule;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'+ Log Service'**
  String get logService;

  /// Title in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Engine Oil & Filter'**
  String get engineOilFilter;

  /// DueText in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Due in 320 km'**
  String get due320Km;

  /// Title in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Chain Clean & Lube'**
  String get chainCleanLube;

  /// DueText in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Good for 850 km'**
  String get good850Km;

  /// Title in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Brake Fluid Flush'**
  String get brakeFluidFlush;

  /// DueText in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Good for 2,100 km'**
  String get good2100Km;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'★ 4.9 · Verified Pure Fuel · Open 24/7'**
  String get n49VerifiedPure;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Rider Feed'**
  String get riderFeed;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'2h ago'**
  String get n2hAgo;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Morning twisties through 300 Feet Highway!'**
  String get morningTwistiesThrough300;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Privacy Zone: 200m Endpoints Clipped'**
  String get privacyZone200mEndpoints;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Road Captain · Dhaka Metro'**
  String get roadCaptainDhakaMetro;

  /// _statCol in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'KM RIDDEN'**
  String get kmRidden;

  /// _statCol in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'SAFETY SCORE'**
  String get safetyScore;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'SafeQR Offline Medical Card'**
  String get safeqrOfflineMedicalCard;

  /// Text in onboarding_ui_mockups.
  ///
  /// In en, this message translates to:
  /// **'Blood: O+ · ICE Emergency SOS Armed'**
  String get bloodOIceEmergency;

  /// Text in tour_floating_banner.
  ///
  /// In en, this message translates to:
  /// **'GUIDE · {slideIndex} OF {total}'**
  String guideProgressDot(Object slideIndex, Object total);

  /// Text in tour_floating_banner.
  ///
  /// In en, this message translates to:
  /// **'Back to Tour'**
  String get backTour;

  /// Text in tour_floating_banner.
  ///
  /// In en, this message translates to:
  /// **'Next →'**
  String get next;

  /// Tooltip in tour_floating_banner.
  ///
  /// In en, this message translates to:
  /// **'Close guide'**
  String get closeGuide;
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
