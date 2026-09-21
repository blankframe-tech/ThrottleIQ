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

  /// Subject in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ live ride'**
  String get throttleiqLiveRide;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Live sharing stopped'**
  String get liveSharingStopped;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Discard this ride?'**
  String get discardThisRide;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'{distance} over {duration} will be deleted. This ride will not be saved to your history and cannot be recovered.'**
  String overWillBeDeleted(Object distance, Object duration);

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Keep recording'**
  String get keepRecording;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Tooltip in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Live sharing on'**
  String get liveSharing;

  /// Tooltip in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Turn on & share live location'**
  String get turnShareLiveLocation;

  /// Label in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceLabel;

  /// Label in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Avg Speed'**
  String get avgSpeed;

  /// Label in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'End Ride'**
  String get endRide;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Discard ride'**
  String get discardRide;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride kept from last time'**
  String get rideKeptFromLast;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Resume to carry on, or discard it to start fresh.'**
  String get resumeCarryDiscardIt;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'CRASH DETECTED'**
  String get crashDetected;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'Are you OK? Your emergency contacts will be notified when the timer ends.'**
  String get okEmergencyContactsWill;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'I\'M OK'**
  String get imOk;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'BRAKE'**
  String get brakeCaps;

  /// Text in active_ride_screen.
  ///
  /// In en, this message translates to:
  /// **'ACCEL'**
  String get accelCaps;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Turn on Location'**
  String get turnOnLocation;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get openAppSettings;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Report a Problem'**
  String get reportProblem;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'No bike yet'**
  String get noBikeYet;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Add the bike you ride and ThrottleIQ can start tracking it.'**
  String get addBikeRideThrottleiq;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Add a bike'**
  String get addABike;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get backgroundLocation;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ records your route, speed, and distance using your location while a ride is active — including while your phone is locked or in a pocket, so the ride isn\'t cut short. The next screen will ask for \"Allow all the time\" location access. Location is only used to record your ride, and tracking stops the moment you end it.'**
  String get backgroundLocationRationale;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Label in record_screen.
  ///
  /// In en, this message translates to:
  /// **'TURN ON'**
  String get turnOnCaps;

  /// Label in record_screen.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsCaps;

  /// Text in record_screen.
  ///
  /// In en, this message translates to:
  /// **'Slide to start ride'**
  String get slideStartRide;

  /// Tooltip in ride_summary_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Text in ride_summary_screen.
  ///
  /// In en, this message translates to:
  /// **'Fetching route…'**
  String get fetchingRoute;

  /// Text in ride_summary_screen.
  ///
  /// In en, this message translates to:
  /// **'Route not available'**
  String get routeNotAvailable;

  /// Tooltip in ride_summary_screen.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get zoomIn;

  /// Tooltip in ride_summary_screen.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get zoomOut;

  /// Tooltip in ride_summary_screen.
  ///
  /// In en, this message translates to:
  /// **'Recenter Route'**
  String get recenterRoute;

  /// Tooltip in ride_summary_screen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen Map'**
  String get fullscreenMap;

  /// Text in auto_detection_history_sheet.
  ///
  /// In en, this message translates to:
  /// **'Ride Recorded'**
  String get rideRecorded;

  /// Text in auto_detection_history_sheet.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get unknownDate;

  /// Text in auto_detection_history_sheet.
  ///
  /// In en, this message translates to:
  /// **'SAVED'**
  String get savedCaps;

  /// Text in auto_detection_history_sheet.
  ///
  /// In en, this message translates to:
  /// **'DISCARDED'**
  String get discardedCaps;

  /// Text in auto_detection_history_sheet.
  ///
  /// In en, this message translates to:
  /// **'Brief trip not classified as ride'**
  String get briefTripNotClassified;

  /// Text in auto_tracking_tile.
  ///
  /// In en, this message translates to:
  /// **'Active hours'**
  String get activeHours;

  /// Text in auto_tracking_tile.
  ///
  /// In en, this message translates to:
  /// **'Only watching for rides between {startMinutes} and {endMinutes}.'**
  String onlyWatchingRidesBetween(Object startMinutes, Object endMinutes);

  /// Text in auto_tracking_tile.
  ///
  /// In en, this message translates to:
  /// **'Watching for rides all day.'**
  String get watchingRidesAllDay;

  /// Label in auto_tracking_tile.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// Label in auto_tracking_tile.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get untilLabel;

  /// Text in auto_tracking_tile.
  ///
  /// In en, this message translates to:
  /// **'The start time must be before the end time.'**
  String get startTimeMustBe;

  /// Text in end_ride_sheet.
  ///
  /// In en, this message translates to:
  /// **'End ride?'**
  String get endRideQuestion;

  /// Text in end_ride_sheet.
  ///
  /// In en, this message translates to:
  /// **'Your ride will be saved.'**
  String get rideWillBeSaved;

  /// Text in end_ride_sheet.
  ///
  /// In en, this message translates to:
  /// **'Share ride after saving'**
  String get shareRideAfterSaving;

  /// Text in end_ride_sheet.
  ///
  /// In en, this message translates to:
  /// **'Keep riding'**
  String get keepRiding;

  /// Label in end_ride_sheet.
  ///
  /// In en, this message translates to:
  /// **'End ride. Press and hold.'**
  String get endRidePressHold;

  /// Text in end_ride_sheet.
  ///
  /// In en, this message translates to:
  /// **'Keep holding…'**
  String get keepHolding;

  /// Text in end_ride_sheet.
  ///
  /// In en, this message translates to:
  /// **'Hold to end ride'**
  String get holdEndRide;

  /// Label in hold_to_start_button.
  ///
  /// In en, this message translates to:
  /// **'Start ride. Press and hold.'**
  String get startRidePressHold;

  /// Text in hold_to_start_button.
  ///
  /// In en, this message translates to:
  /// **'GO'**
  String get goCaps;

  /// Text in hold_to_start_button.
  ///
  /// In en, this message translates to:
  /// **'HOLD'**
  String get holdCaps;

  /// Android foreground-service notification body while a rider-started ride records.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ is recording your ride in the background'**
  String get recordingNotificationTextUser;

  /// Android foreground-service notification body while an auto-detected ride records.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ detected a ride and is recording it'**
  String get recordingNotificationTextAuto;

  /// Foreground-service notification title for a rider-started ride.
  ///
  /// In en, this message translates to:
  /// **'Ride Recording Active'**
  String get rideRecordingActive;

  /// Foreground-service notification title for an auto-detected ride.
  ///
  /// In en, this message translates to:
  /// **'Ride Detected'**
  String get rideDetected;

  /// Error shown on the Record screen when device location services are off.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off. Turn on Location Services to start a ride.'**
  String get recordingLocationOff;

  /// Error shown on the Record screen when location permission was denied.
  ///
  /// In en, this message translates to:
  /// **'ThrottleIQ needs location permission to track your ride. Grant it in Settings.'**
  String get recordingPermissionDenied;

  /// Error shown when the rider tries to record with no bike.
  ///
  /// In en, this message translates to:
  /// **'Please add a bike before recording a ride.'**
  String get addBikeBeforeRecording;

  /// FromName in notification_repository (+2 more).
  ///
  /// In en, this message translates to:
  /// **'A rider'**
  String get aRider;

  /// SetState in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Live positions unavailable: {e}'**
  String livePositionsUnavailable(Object e);

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Location permission is off — the group can\'t see you. You can still see them.'**
  String get locationPermissionOffGroup;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable: {e}'**
  String locationUnavailable(Object e);

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Leave group ride?'**
  String get leaveGroupRide;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'The others stop seeing your position. Your own ride recording keeps running — end it from the ride screen.'**
  String get othersStopSeeingPosition;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t leave: {e}'**
  String couldntLeave(Object e);

  /// SetState in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off — you can still hear the group.'**
  String get microphoneAccessOffCan;

  /// SetState in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start recording: {e}'**
  String couldntStartRecording(Object e);

  /// SetState in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send voice note: {e}'**
  String couldntSendVoiceNote(Object e);

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Group ride'**
  String get groupRide;

  /// Message in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'This group ride no longer exists.'**
  String get thisGroupRideNo;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Recording — release to send'**
  String get recordingReleaseSend;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Playing {note}…'**
  String playing(Object note);

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get holdTalk;

  /// Tooltip in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Unmute voice notes'**
  String get unmuteVoiceNotes;

  /// Tooltip in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Mute voice notes'**
  String get muteVoiceNotes;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Nobody is on this ride yet.'**
  String get nobodyThisRideYet;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Riding — {joinedCount}'**
  String ridingJoined(Object joinedCount);

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Invited — {pendingCount} waiting'**
  String invitedWaiting(Object pendingCount);

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Hasn\'t joined yet'**
  String get hasntJoinedYet;

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'{userName} (you)'**
  String you(Object userName);

  /// Text in group_ride_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first position…'**
  String get waitingFirstPosition;

  /// Text in my_shared_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete shared ride?'**
  String get deleteSharedRide;

  /// Text in my_shared_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'This removes it from the feed for everyone. Your local ride history is unaffected.'**
  String get thisRemovesItFrom;

  /// Text in forum_thread_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Text in my_shared_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'My Shared Rides'**
  String get mySharedRides;

  /// Text in my_shared_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t shared any rides yet'**
  String get haventSharedAnyRides;

  /// Text in notifications_screen.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Text in notifications_screen.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// Text in notifications_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join the ride: {e}'**
  String couldntJoinRide(Object e);

  /// Text in notifications_screen.
  ///
  /// In en, this message translates to:
  /// **'{relativeTime} · tap to join'**
  String tapJoin(Object relativeTime);

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Anyone on ThrottleIQ'**
  String get anyoneThrottleiq;

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'People who follow you'**
  String get peopleWhoFollow;

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Riders you follow each other'**
  String get ridersFollowEachOther;

  /// _showCapMessage in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'You can add up to {maxRidePhotos} photos. Remove one to add another.'**
  String canAddUpPhotos(Object maxRidePhotos);

  /// _showCapMessage in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Only {maxRidePhotos} photos per ride — kept the first {remaining}.'**
  String onlyPhotosPerRide(Object maxRidePhotos, Object remaining);

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride shared'**
  String get rideShared;

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Saved — we\'ll post it when you\'re back online'**
  String get savedWellPostIt;

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Failed to share ride: {e}'**
  String failedShareRide(Object e);

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Add up to {maxRidePhotos} ride or bike photos'**
  String addUpRideBike(Object maxRidePhotos);

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Share ride'**
  String get shareRide;

  /// HintText in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Say something about this ride'**
  String get saySomethingAboutThis;

  /// EditorialLabel in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Photos (optional)'**
  String get photosOptional;

  /// EditorialLabel in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Who can see this'**
  String get whoCanSeeThis;

  /// Text in ride_share_screen.
  ///
  /// In en, this message translates to:
  /// **'Save as route'**
  String get saveAsRoute;

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Route saved to My Routes!'**
  String get routeSavedMyRoutes;

  /// Text in shared_ride_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Failed to post comment: {e}'**
  String failedPostComment(Object e);

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Vote failed: {e}'**
  String voteFailed(Object e);

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not save route: {e}'**
  String couldNotSaveRoute(Object e);

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride Details'**
  String get rideDetails;

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride not found or removed'**
  String get rideNotFoundRemoved;

  /// Text in shared_ride_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Report Ride'**
  String get reportRide;

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'No GPS track available for this ride'**
  String get noGpsTrackAvailable;

  /// EditorialLabel in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Speed & Performance Details'**
  String get speedPerformanceDetails;

  /// Title in shared_ride_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Max Speed'**
  String get maxSpeed;

  /// Title in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Riding Pace'**
  String get ridingPace;

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'{polylineCount} track points'**
  String trackPoints(Object polylineCount);

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Start: '**
  String get startColon;

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Finish: '**
  String get finishColon;

  /// EditorialLabel in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride Photos'**
  String get ridePhotos;

  /// Tooltip in forum_thread_screen (+2 more).
  ///
  /// In en, this message translates to:
  /// **'Upvote'**
  String get upvote;

  /// Tooltip in forum_thread_screen (+2 more).
  ///
  /// In en, this message translates to:
  /// **'Downvote'**
  String get downvote;

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'{comments} comments'**
  String commentsCount(Object comments);

  /// Text in shared_ride_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first to comment!'**
  String get noCommentsYetBe;

  /// HintText in shared_ride_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get addComment;

  /// Tooltip in chat_room_screen (+3 more).
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// HintText in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Search riders and forums'**
  String get searchRidersForums;

  /// Tooltip in chat_list_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Forums'**
  String get forums;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for \"{query}\".\nTry a @username, an email, or a forum name.'**
  String nothingFoundTryUsername(Object query);

  /// _SectionMessage in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search riders: {error}'**
  String couldntSearchRiders(Object error);

  /// _SectionMessage in social_screen.
  ///
  /// In en, this message translates to:
  /// **'No riders match that.'**
  String get noRidersMatchThat;

  /// _SectionMessage in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search forums: {error}'**
  String couldntSearchForums(Object error);

  /// _SectionMessage in social_screen.
  ///
  /// In en, this message translates to:
  /// **'No forums match that.'**
  String get noForumsMatchThat;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'{followerCount} followers · {postCount} posts'**
  String followersPosts(Object followerCount, Object postCount);

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing from your riders yet'**
  String get nothingFromRidersYet;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'No rides yet'**
  String get noRidesYet;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Search for riders above and follow them to fill this in.'**
  String get searchRidersAboveFollow;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Share a ride from its summary screen to get things started.'**
  String get shareRideFromIts;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get youreAllCaughtUp;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noCommentsYet;

  /// Text in social_screen.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// Text in forum_thread_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// Text in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'Ride with friends'**
  String get rideWithFriends;

  /// Text in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'{selectedCount}/{maxGroupRideFriends} selected'**
  String selectedCount(Object selectedCount, Object maxGroupRideFriends);

  /// Text in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'Pick {minGroupRideFriends}–{maxGroupRideFriends} riders. Your ride starts recording right away; they join from their notifications.'**
  String pickRidersRideStarts(
      Object minGroupRideFriends, Object maxGroupRideFriends);

  /// HintText in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'@username or email'**
  String get usernameEmail;

  /// Text in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'Start group ride'**
  String get startGroupRide;

  /// Text in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'Start group ride with {selectedCount}'**
  String startGroupRideWithCount(Object selectedCount);

  /// Text in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'Search by @username or email'**
  String get searchByUsernameEmail;

  /// Text in group_ride_friend_picker.
  ///
  /// In en, this message translates to:
  /// **'No riders found'**
  String get noRidersFound;

  /// Name in ride_mode_selector.
  ///
  /// In en, this message translates to:
  /// **'{inviterName}\'s group ride'**
  String inviterGroupRide(Object inviterName);

  /// Text in ride_mode_selector.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the group ride: {e}'**
  String couldntStartGroupRide(Object e);

  /// Text in create_forum_screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create a forum.'**
  String get signCreateForum;

  /// Text in create_forum_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not create the forum: {e}'**
  String couldNotCreateForum(Object e);

  /// Text in create_forum_screen.
  ///
  /// In en, this message translates to:
  /// **'Create a forum'**
  String get createForum;

  /// HintText in create_forum_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sunday Breakfast Rides'**
  String get eGSundayBreakfast;

  /// Text in create_forum_screen.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// HintText in create_forum_screen.
  ///
  /// In en, this message translates to:
  /// **'What\'s this forum about?'**
  String get whatsThisForumAbout;

  /// Text in create_forum_screen.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be able to moderate posts here and add other riders as maintainers.'**
  String get youllBeAbleModerate;

  /// Text in create_forum_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Text in forum_post_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Failed to post reply: {e}'**
  String failedPostReply(Object e);

  /// Text in forum_post_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// Text in forum_post_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Post not found'**
  String get postNotFound;

  /// Text in forum_post_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'No replies yet — be the first to help out.'**
  String get noRepliesYetBe;

  /// HintText in forum_post_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Write a reply...'**
  String get writeReply;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get forum;

  /// Tooltip in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// Tooltip in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Manage maintainers'**
  String get manageMaintainers;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPost;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Be the first to ask a question or share something.'**
  String get beFirstAskQuestion;

  /// HintText in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// ErrorText in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// HintText in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'What\'s going on?'**
  String get whatsGoing;

  /// ErrorText in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Say something before posting'**
  String get saySomethingBeforePosting;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t record your vote — check your connection and try again.'**
  String get couldntRecordVoteCheck;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get deletePostQuestion;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'This removes the post and its replies from the forum. It cannot be undone.'**
  String get thisRemovesPostIts;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not delete: {e}'**
  String couldNotDelete(Object e);

  /// Tooltip in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePost;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Report Post'**
  String get reportPost;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'from {displayName}'**
  String fromUser(Object displayName);

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not update maintainers: {e}'**
  String couldNotUpdateMaintainers(Object e);

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Maintainers'**
  String get maintainers;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Maintainers can delete posts and replies in this forum.'**
  String get maintainersCanDeletePosts;

  /// Text in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'No maintainers yet.'**
  String get noMaintainersYet;

  /// Tooltip in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// HintText in forum_thread_screen.
  ///
  /// In en, this message translates to:
  /// **'Add by rider UID'**
  String get addByRiderUid;

  /// Text in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not open forum: {e}'**
  String couldNotOpenForum(Object e);

  /// Text in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Your bikes'**
  String get yourBikes;

  /// Text in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Add a bike to your garage to see its forum here.'**
  String get addBikeGarageSee;

  /// Text in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Rider forums'**
  String get riderForums;

  /// Text in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'No rider-made forums yet. Create the first one.'**
  String get noRiderMadeForums;

  /// Text in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Find a forum'**
  String get findForum;

  /// HintText in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Search a brand, e.g. Yamaha'**
  String get searchBrandEG;

  /// Tooltip in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Search forums'**
  String get searchForums;

  /// Label in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Brands'**
  String get brands;

  /// Label in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get topics;

  /// Text in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'{postCount} posts · {followerCount} followers'**
  String postsFollowers(Object postCount, Object followerCount);

  /// Tooltip in forums_home_screen.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettings;

  /// Tooltip in chat_list_screen.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessage;

  /// Text in chat_list_screen.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get newMessageTitle;

  /// Text in chat_list_screen.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// Text in chat_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Start a Conversation'**
  String get startConversation;

  /// Text in chat_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Text in chat_list_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Say hi!'**
  String get sayHi;

  /// HintText in chat_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Search rider by @username or email...'**
  String get searchRiderByUsername;

  /// Text in chat_list_screen.
  ///
  /// In en, this message translates to:
  /// **'No riders found for \"{text}\"'**
  String noRidersFoundFor(Object text);

  /// Label in chat_room_screen.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Text in chat_room_screen.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Text in chat_room_screen.
  ///
  /// In en, this message translates to:
  /// **'You can\'t message this rider'**
  String get cantMessageThisRider;

  /// HintText in chat_room_screen.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get messageHint;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Spam or misleading'**
  String get spamMisleading;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get harassmentBullying;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Hate speech'**
  String get hateSpeech;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get inappropriateContent;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Report submitted successfully. We will review it shortly.'**
  String get reportSubmittedSuccessfullyWe;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report: {e}'**
  String failedSubmitReport(Object e);

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get whyReportingThis;

  /// LabelText in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get additionalDetailsOptional;

  /// Text in report_bottom_sheet.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// Post audience option: visible to everyone on ThrottleIQ.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get audiencePublic;

  /// Post audience option: visible to people who follow the rider.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get audienceFollowers;

  /// Post audience option: visible to riders who follow each other.
  ///
  /// In en, this message translates to:
  /// **'Mutual'**
  String get audienceMutual;

  /// Report reason option (label only; the stored value stays English).
  ///
  /// In en, this message translates to:
  /// **'Self-harm'**
  String get selfHarm;

  /// Report reason option (label only; the stored value stays English).
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherReason;

  /// Message body sent with the live-ride link when the rider shares it (the rider's own outgoing text).
  ///
  /// In en, this message translates to:
  /// **'Follow my ride live: {url}'**
  String followMyRideLive(String url);

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Log Service'**
  String get logServiceTitle;

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get serviceType;

  /// LabelText in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'What did you service? *'**
  String get whatDidService;

  /// HintText in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Radiator flush'**
  String get eGRadiatorFlush;

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Name the service'**
  String get nameService;

  /// LabelText in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Odometer (km) *'**
  String get odometerKm;

  /// Text in add_maintenance_log_screen (+3 more).
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// LabelText in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Cost (optional)'**
  String get costOptional;

  /// LabelText in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// HintText in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Configured spec: {specNote}'**
  String configuredSpec(Object specNote);

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Octane 95, 12L fill-up, Jamuna oil...'**
  String get eGOctane95;

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Used Motul 10W40...'**
  String get eGUsedMotul;

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Insert spec: {specNote}'**
  String insertSpec(Object specNote);

  /// Text in add_maintenance_log_screen.
  ///
  /// In en, this message translates to:
  /// **'Save Service Log'**
  String get saveServiceLog;

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'Your Motorcycle'**
  String get yourMotorcycle;

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'Setup Maintenance'**
  String get setupMaintenance;

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'Edit Tracked Checks'**
  String get editTrackedChecks;

  /// Text in maintenance_config_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'What would you like to track for {bikeName}?'**
  String whatWouldLikeTrack(Object bikeName);

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'Select the components you want ThrottleIQ to monitor. We will calculate wear based on your odometer and notify you before services are due.'**
  String get selectComponentsWantThrottleiq;

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// Text in maintenance_config_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// Text in maintenance_config_screen (+2 more).
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'Track {enabledCount} Checks'**
  String trackChecks(Object enabledCount);

  /// Text in maintenance_config_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Save Preferences'**
  String get savePreferences;

  /// Text in maintenance_config_screen.
  ///
  /// In en, this message translates to:
  /// **'{activeInCategory} of {categoryItemsCount} active'**
  String activeInCategory(Object activeInCategory, Object categoryItemsCount);

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'No active bike'**
  String get noActiveBike;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Add a motorcycle to your garage to track maintenance.'**
  String get addMotorcycleGarageTrack;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Sync Odo'**
  String get syncOdo;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get log;

  /// Message in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Reset service log'**
  String get resetServiceLog;

  /// EditorialLabel in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Tracked checks'**
  String get trackedChecks;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'{remindersCount} monitored'**
  String monitored(Object remindersCount);

  /// Label in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'All ({remindersCount})'**
  String filterAll(Object remindersCount);

  /// Label in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Attention ({attentionCount})'**
  String filterAttention(Object attentionCount);

  /// Label in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'OK ({okCount})'**
  String filterOk(Object okCount);

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'No checks tracked yet. Tap \"Customize\" above to select checks.'**
  String get noChecksTrackedYet;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'No checks matching this filter.'**
  String get noChecksMatchingThis;

  /// EditorialLabel in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Service history'**
  String get serviceHistory;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Total: ৳{totalCost}'**
  String total(Object totalCost);

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'No service records logged yet.'**
  String get noServiceRecordsLogged;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'When you service your bike, log it here to reset intervals.'**
  String get whenServiceBikeLog;

  /// Tooltip in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Switch bike'**
  String get switchBike;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchAction;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Immediate maintenance attention recommended'**
  String get immediateMaintenanceAttentionRecommended;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Upcoming scheduled maintenance'**
  String get upcomingScheduledMaintenance;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'All Systems Nominal'**
  String get allSystemsNominal;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'All {total} tracked components in good health'**
  String allTrackedComponentsGood(Object total);

  /// _metricPill in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Due Soon'**
  String get dueSoonTitle;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'What would you like to maintain?'**
  String get whatWouldLikeMaintain;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Not everyone wants to track everything. Pick the items you care about for {displayName}, or tap to edit intervals and add specs (oil brand, tyre dates/sizes):'**
  String notEveryoneWantsTrack(Object displayName);

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Essentials (4)'**
  String get essentials4;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'All 8 items'**
  String get all8Items;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Saving Preferences...'**
  String get savingPreferences;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking ({enabledCount} Items)'**
  String startTrackingItems(Object enabledCount);

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'See all 20+ checks & advanced setup'**
  String get seeAll20Checks;

  /// Text in maintenance_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get dueSoon;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Every {imperial}'**
  String intervalEvery(Object imperial);

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Last done: {lastServiceDate}'**
  String lastDone(Object lastServiceDate);

  /// Text in maintenance_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'No previous service recorded'**
  String get noPreviousServiceRecorded;

  /// Text in maintenance_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete Log'**
  String get deleteLog;

  /// Text in maintenance_screen.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this {displayLabel} record?'**
  String sureWantDeleteThis(Object displayLabel);

  /// Text in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Track on Dashboard'**
  String get trackDashboard;

  /// Text in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Calculate wear and monitor interval'**
  String get calculateWearMonitorInterval;

  /// EditorialLabel in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Service Interval'**
  String get serviceInterval;

  /// LabelText in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Interval Distance (km)'**
  String get intervalDistanceKm;

  /// Text in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get enterPositiveNumber;

  /// EditorialLabel in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Specifications & Extra Info'**
  String get specificationsExtraInfo;

  /// Text in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Optional text'**
  String get optionalText;

  /// LabelText in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Specs (oil grade, tyre sizes & dates...)'**
  String get specsOilGradeTyre;

  /// Text in edit_maintenance_check_sheet.
  ///
  /// In en, this message translates to:
  /// **'Visible on your maintenance card for quick reference.'**
  String get visibleMaintenanceCardQuick;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Odometer synced to {newKm} km!'**
  String odometerSyncedKm(Object newKm);

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Sync Odometer'**
  String get syncOdometer;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Align ThrottleIQ with {displayName}'**
  String alignThrottleiqWith(Object displayName);

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Rode offline or without phone tracking? Take a photo of your bike\'s dashboard/speedometer cluster or enter the current reading below.'**
  String get rodeOfflineWithoutPhone;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Scanning instrument cluster...'**
  String get scanningInstrumentCluster;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'From Photos'**
  String get fromPhotos;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Current App Odometer:'**
  String get currentAppOdometer;

  /// LabelText in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Physical Instrument Cluster Reading *'**
  String get physicalInstrumentClusterReading;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Enter valid positive number'**
  String get enterValidPositiveNumber;

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'+{delta} km added (offline riding accounted for)'**
  String kmAddedOfflineRiding(Object delta);

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'{delta} km reduction (calibrating baseline)'**
  String kmReductionCalibratingBaseline(Object delta);

  /// Text in odometer_sync_sheet.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Sync Odometer'**
  String get confirmSyncOdometer;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'Reset selected items?'**
  String get resetSelectedItems;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'This logs \"{label}\" as serviced today at the bike\'s current odometer, resetting its due date. Past history is kept.'**
  String thisLogsAsServiced(Object label);

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'This logs {selectedCount} items as serviced today at the bike\'s current odometer, resetting their due dates. Past history is kept.'**
  String thisLogsItemsAs(Object selectedCount);

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'1 item reset to serviced today.'**
  String get n1ItemResetServiced;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'{count} items reset to serviced today.'**
  String itemsResetServicedToday(Object count);

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'Reset Service Log'**
  String get resetServiceLogTitle;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'Tick what you just serviced on {displayName}'**
  String tickWhatJustServiced(Object displayName);

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'Selected items are logged as serviced today at the current odometer, resetting their due date. Nothing is deleted.'**
  String get selectedItemsLoggedAs;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'No tracked checks yet. Set some up under \"Customize\" first.'**
  String get noTrackedChecksYet;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'{selectedCount} of {remindersCount} selected'**
  String selectedOfTotal(Object selectedCount, Object remindersCount);

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'Select items to reset'**
  String get selectItemsReset;

  /// Text in reset_maintenance_log_sheet.
  ///
  /// In en, this message translates to:
  /// **'Last done {kmSinceService} km ago'**
  String lastDoneKmAgo(Object kmSinceService);

  /// Title in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Crop bike photo'**
  String get cropBikePhoto;

  /// Text in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Bike added.'**
  String get bikeAdded;

  /// Label in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Set service intervals'**
  String get setServiceIntervals;

  /// Text in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Edit Bike'**
  String get editBike;

  /// Text in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// Text in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// Text in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// LabelText in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Odometer reading (km)'**
  String get odometerReadingKm;

  /// Text in add_edit_bike_screen.
  ///
  /// In en, this message translates to:
  /// **'Bike color'**
  String get bikeColor;

  /// Text in add_edit_bike_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Bike not found'**
  String get bikeNotFound;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'{displayName} (archived)'**
  String archived(Object displayName);

  /// Tooltip in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Discuss this bike'**
  String get discussThisBike;

  /// Tooltip in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Unarchive bike'**
  String get unarchiveBike;

  /// Tooltip in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Archive or delete bike'**
  String get archiveDeleteBike;

  /// Label in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get totalDistance;

  /// Label in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Total Rides'**
  String get totalRides;

  /// Label in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get odometer;

  /// Label in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engine;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride History'**
  String get rideHistory;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'No rides yet for this bike'**
  String get noRidesYetThis;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Remove {displayName}?'**
  String removeBikeQuestion(Object displayName);

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Archiving hides this bike from your garage and bike pickers. Its rides stay in your history and stats, and you can unarchive it any time.'**
  String get archivingHidesThisBike;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete bike and all its rides'**
  String get deleteBikeAllIts;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Archive bike (keep rides)'**
  String get archiveBikeKeepRides;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not archive this bike: {e}'**
  String couldNotArchiveThis(Object e);

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this bike: {e}'**
  String couldNotDeleteThis(Object e);

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Bike is back in your garage'**
  String get bikeBackGarage;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not unarchive this bike: {e}'**
  String couldNotUnarchiveThis(Object e);

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete bike and all its rides?'**
  String get deleteBikeQuestion;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Using default service intervals'**
  String get usingDefaultServiceIntervals;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Service & maintenance'**
  String get serviceMaintenance;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Next: {summary}'**
  String nextSummary(Object summary);

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get intervals;

  /// Text in bike_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'Your Bikes'**
  String get yourBikesTitle;

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'My Places'**
  String get myPlaces;

  /// Text in garage_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'No bikes yet'**
  String get noBikesYet;

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'Add your first bike to get started'**
  String get addFirstBikeGet;

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'Set active'**
  String get setActive;

  /// Label in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get totalLower;

  /// Label in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'rides'**
  String get ridesLower;

  /// Label in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'last ride'**
  String get lastRide;

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'Archived bikes ({bikesCount})'**
  String archivedBikes(Object bikesCount);

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'{rideCount} rides · {totalDistanceM}'**
  String ridesAndDistance(Object rideCount, Object totalDistanceM);

  /// Text in garage_screen.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// Text in bike_visibility.
  ///
  /// In en, this message translates to:
  /// **'My followers'**
  String get myFollowers;

  /// Text in bike_visibility (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Only me'**
  String get onlyMe;

  /// Text in blocked_users_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// Text in blocked_users_screen.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// Text in blocked_users_screen.
  ///
  /// In en, this message translates to:
  /// **'Error loading user'**
  String get errorLoadingUser;

  /// Text in blocked_users_screen.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// Text in blocked_users_screen.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile: {e}'**
  String couldNotSaveProfile(Object e);

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// LabelText in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// LabelText in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// HintText in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Shown on cards & feed'**
  String get shownCardsFeed;

  /// LabelText in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameField;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'3-20 letters, numbers or underscore'**
  String get n320LettersNumbers;

  /// LabelText in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Who can see my profile'**
  String get whoCanSeeProfile;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Mutuals'**
  String get mutuals;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Who can see my bikes'**
  String get whoCanSeeBikes;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Your garage on your profile. Separate from who can see the profile itself.'**
  String get garageProfileSeparateFrom;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Tell riders about yourself'**
  String get tellRidersAboutYourself;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'A good bio gets you more followers.'**
  String get goodBioGetsMore;

  /// HintText in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"FZ-S rider from Dhaka. Weekend tourer. Coffee & corners.\"'**
  String get eGFzS;

  /// Text in edit_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Save bio'**
  String get saveBio;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety'**
  String get privacySafety;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts you have blocked'**
  String get manageAccountsHaveBlocked;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'See Demo & Feature Tour'**
  String get seeDemoFeatureTour;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Replay interactive feature guides and safety walkthrough'**
  String get replayInteractiveFeatureGuides;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Send Bug Report'**
  String get sendBugReport;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Something broken? Let the team know'**
  String get somethingBrokenLetTeam;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountQuestion;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your recorded rides, bike profiles, stats, and personal data will be permanently deleted.'**
  String get thisActionIrreversibleAll;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanently;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get deletingAccount;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'Error deleting account: {e}'**
  String errorDeletingAccount(Object e);

  /// Text in settings_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Sync issues'**
  String get syncIssues;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'1 update couldn\'t be sent'**
  String get n1UpdateCouldntBe;

  /// Text in settings_screen.
  ///
  /// In en, this message translates to:
  /// **'{count} updates couldn\'t be sent'**
  String updatesCouldntBeSent(Object count);

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Ride share'**
  String get rideShare;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Ending a live share'**
  String get endingLiveShare;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Maintenance log'**
  String get maintenanceLog;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Cloud update'**
  String get cloudUpdate;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Everything is synced'**
  String get everythingSynced;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync yet. We\'ll keep trying in the background.'**
  String get couldntSyncYetWell;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'Discard this update?'**
  String get discardThisUpdate;

  /// Text in sync_issues_screen.
  ///
  /// In en, this message translates to:
  /// **'It won\'t be sent. This can\'t be undone.'**
  String get itWontBeSent;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your profile'**
  String get signViewProfile;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get userBlocked;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Report User'**
  String get reportUser;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockUser;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Tap Edit to finish setting up your profile'**
  String get tapEditFinishSetting;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Rider not found'**
  String get riderNotFound;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Riding with us since {createdAt}'**
  String ridingWithUsSince(Object createdAt);

  /// Label in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'followers'**
  String get followersLabel;

  /// Label in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'following'**
  String get followingLabel;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// Label in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'total distance'**
  String get totalDistanceLower;

  /// Label in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'rides logged'**
  String get ridesLogged;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'No badges earned yet'**
  String get noBadgesEarnedYet;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'My garage'**
  String get myGarageLower;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get garage;

  /// Text in user_profile_screen.
  ///
  /// In en, this message translates to:
  /// **'Who can see my bikes — change this under Edit'**
  String get whoCanSeeBikesChangeUnderEdit;

  /// Text in profile_load_error_view.
  ///
  /// In en, this message translates to:
  /// **'This profile is private'**
  String get thisProfilePrivate;

  /// Text in profile_load_error_view.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get youreOffline;

  /// Text in profile_load_error_view.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load profile'**
  String get couldntLoadProfile;

  /// Confirm button in the reset-service-log sheet, with the number of ticked items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Reset 1 Item} other{Reset {count} Items}}'**
  String resetItemsButton(int count);

  /// Body of the delete-bike confirmation; the rider must type the bike's name to confirm.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {rides, plural, =1{1 ride} other{{rides} rides}}, their routes and this bike\'s maintenance log, on this phone and in the cloud. Type \"{expected}\" to confirm.'**
  String deleteBikeConfirmBody(int rides, String expected);

  /// Maintenance item name (oilChange); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Oil Change'**
  String get svcTypeOilChange;

  /// Maintenance item name (airFilter); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Air Filter'**
  String get svcTypeAirFilter;

  /// Maintenance item name (chain); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Chain Lube'**
  String get svcTypeChain;

  /// Maintenance item name (tire); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Tire Check'**
  String get svcTypeTire;

  /// Maintenance item name (radiatorCoolant); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Radiator / Coolant'**
  String get svcTypeRadiatorCoolant;

  /// Maintenance item name (frontDiscPads); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Front Disc Pads'**
  String get svcTypeFrontDiscPads;

  /// Maintenance item name (rearDrumPads); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Rear Drum Pads'**
  String get svcTypeRearDrumPads;

  /// Maintenance item name (brakeFluid); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Brake Fluid'**
  String get svcTypeBrakeFluid;

  /// Maintenance item name (sparkPlug); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Spark Plug'**
  String get svcTypeSparkPlug;

  /// Maintenance item name (battery); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get svcTypeBattery;

  /// Maintenance item name (valveClearance); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Valve Clearance'**
  String get svcTypeValveClearance;

  /// Maintenance item name (clutchCable); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Clutch Cable'**
  String get svcTypeClutchCable;

  /// Maintenance item name (suspension); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Suspension'**
  String get svcTypeSuspension;

  /// Maintenance item name (oilFilter); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Oil Filter'**
  String get svcTypeOilFilter;

  /// Maintenance item name (chainTension); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Chain Slack & Tension'**
  String get svcTypeChainTension;

  /// Maintenance item name (brakeRotors); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Brake Rotors / Discs'**
  String get svcTypeBrakeRotors;

  /// Maintenance item name (forkSeals); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Fork Oil & Seals'**
  String get svcTypeForkSeals;

  /// Maintenance item name (wheelBearings); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Wheel Bearings'**
  String get svcTypeWheelBearings;

  /// Maintenance item name (driveBelt); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Drive Belt'**
  String get svcTypeDriveBelt;

  /// Maintenance item name (throttleCables); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Throttle & Cables'**
  String get svcTypeThrottleCables;

  /// Maintenance item name (fuel); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get svcTypeFuel;

  /// Maintenance item name (custom); the stored id stays the enum name.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get svcTypeCustom;

  /// One-line description of the oilChange maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Drain engine oil & replace with fresh lubricant.'**
  String get svcDescOilChange;

  /// One-line description of the oilFilter maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Replace oil filter element to prevent contaminant buildup.'**
  String get svcDescOilFilter;

  /// One-line description of the airFilter maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Clean or replace intake filter for optimal airflow.'**
  String get svcDescAirFilter;

  /// One-line description of the chain maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Clean road grime & apply chain lube to drive chain.'**
  String get svcDescChain;

  /// One-line description of the chainTension maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Check drive chain slack & align rear axle.'**
  String get svcDescChainTension;

  /// One-line description of the tire maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Inspect tire pressures, tread wear & dry rot.'**
  String get svcDescTire;

  /// One-line description of the radiatorCoolant maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Flush and refill radiator coolant fluid.'**
  String get svcDescRadiatorCoolant;

  /// One-line description of the frontDiscPads maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Check front brake pad friction material thickness.'**
  String get svcDescFrontDiscPads;

  /// One-line description of the rearDrumPads maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Inspect rear brake pads or drum brake shoes.'**
  String get svcDescRearDrumPads;

  /// One-line description of the brakeFluid maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Bleed & replenish hydraulic DOT brake fluid.'**
  String get svcDescBrakeFluid;

  /// One-line description of the sparkPlug maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Inspect electrode gap or replace spark plugs.'**
  String get svcDescSparkPlug;

  /// One-line description of the battery maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Test terminal voltage, connections & charge state.'**
  String get svcDescBattery;

  /// One-line description of the valveClearance maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Measure & adjust intake / exhaust valve clearances.'**
  String get svcDescValveClearance;

  /// One-line description of the clutchCable maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Check lever free-play & lube clutch cable.'**
  String get svcDescClutchCable;

  /// One-line description of the throttleCables maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Inspect throttle play, snap-back & lube cables.'**
  String get svcDescThrottleCables;

  /// One-line description of the suspension maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Inspect rear shock damping & linkage pivot bushings.'**
  String get svcDescSuspension;

  /// One-line description of the forkSeals maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Inspect front fork seals for oil weeping & change fork oil.'**
  String get svcDescForkSeals;

  /// One-line description of the brakeRotors maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Measure brake disc thickness & check for warping.'**
  String get svcDescBrakeRotors;

  /// One-line description of the wheelBearings maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Inspect front & rear wheel bearings for play/roughness.'**
  String get svcDescWheelBearings;

  /// One-line description of the driveBelt maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Check belt deflection, teeth condition & tension.'**
  String get svcDescDriveBelt;

  /// One-line description of the fuel maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Track fuel refills, tank range, and fuel type.'**
  String get svcDescFuel;

  /// One-line description of the custom maintenance item.
  ///
  /// In en, this message translates to:
  /// **'Rider-defined maintenance check.'**
  String get svcDescCustom;

  /// Maintenance category heading (engine).
  ///
  /// In en, this message translates to:
  /// **'Engine & Fluids'**
  String get maintCatEngine;

  /// Maintenance category heading (drivetrain).
  ///
  /// In en, this message translates to:
  /// **'Drive & Controls'**
  String get maintCatDrivetrain;

  /// Maintenance category heading (braking).
  ///
  /// In en, this message translates to:
  /// **'Braking System'**
  String get maintCatBraking;

  /// Maintenance category heading (chassisElectrical).
  ///
  /// In en, this message translates to:
  /// **'Chassis & Electrical'**
  String get maintCatChassisElectrical;

  /// Garage summary line for the most urgent overdue check.
  ///
  /// In en, this message translates to:
  /// **'{item} · overdue by {km} km'**
  String serviceOverdueBy(String item, String km);

  /// Garage summary line for the next check that is coming due.
  ///
  /// In en, this message translates to:
  /// **'{item} · due in {km} km'**
  String serviceDueIn(String item, String km);

  /// Text in place_entity.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Pick the location on the map first.'**
  String get pickLocationMapFirst;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera or gallery: {e}'**
  String couldNotOpenCamera(Object e);

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t look that spot up — just describe it yourself.'**
  String get couldntLookThatSpot;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Photo didn\'t upload — saving the place without it.'**
  String get photoDidntUploadSaving;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not add place: {e}'**
  String couldNotAddPlace(Object e);

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Add a photo (optional)'**
  String get addPhotoOptional;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'A shopfront picture makes this place easy to spot'**
  String get shopfrontPictureMakesThis;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load that photo'**
  String get couldntLoadThatPhoto;

  /// Tooltip in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get replacePhoto;

  /// Tooltip in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Add Place'**
  String get addPlace;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// LabelText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameStar;

  /// HintText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rahman Motors'**
  String get eGRahmanMotors;

  /// LabelText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// HintText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Beside Omuk School, Mirpur 10'**
  String get eGBesideOmuk;

  /// HelperText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Write it the way you\'d tell a friend — landmarks, not a formal street address. \"Beside Omuk School\" or \"just after the Mirpur 10 circle\" helps far more here.'**
  String get writeItWayYoud;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Looking up…'**
  String get lookingUp;

  /// Text in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Use the pin\'s area'**
  String get usePinsArea;

  /// LabelText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// LabelText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'Hours (optional)'**
  String get hoursOptional;

  /// HintText in add_place_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. 9am - 9pm, or 24/7'**
  String get eG9am9pm;

  /// Text in my_places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any places yet'**
  String get haventAddedAnyPlaces;

  /// Text in my_places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'{displayName} · Verified'**
  String verified(Object displayName);

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already reviewed this place.'**
  String get youveAlreadyReviewedThis;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not submit review: {e}'**
  String couldNotSubmitReview(Object e);

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get place;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Place not found'**
  String get placeNotFound;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Add your review'**
  String get addReview;

  /// Tooltip in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Rate this place'**
  String get rateThisPlace;

  /// HintText in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Share your experience...'**
  String get shareExperience;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get submitReview;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet — be the first!'**
  String get noReviewsYetBe;

  /// Text in place_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Official point'**
  String get officialPoint;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'★ 0 (Not on Google)'**
  String get n0NotGoogle;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'★ 0 (0 reviews)'**
  String get n00Reviews;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a maps app for directions'**
  String get couldntOpenMapsApp;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the dialler'**
  String get couldntOpenDialler;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youLabel;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Record this ride in ThrottleIQ?'**
  String get recordThisRideThrottleiq;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Your maps app gives the directions. ThrottleIQ can log the trip in the background at the same time.'**
  String get mapsAppGivesDirections;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Record & go'**
  String get recordGo;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Just directions'**
  String get justDirections;

  /// Text in place_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get dontAskAgain;

  /// Text in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'No new places found nearby'**
  String get noNewPlacesFound;

  /// Text in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not import nearby places: {e}'**
  String couldNotImportNearby(Object e);

  /// Tooltip in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Import nearby places from OpenStreetMap'**
  String get importNearbyPlacesFrom;

  /// Label in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// Text in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Browse routes →'**
  String get browseRoutes;

  /// Text in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Text in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'No places nearby yet'**
  String get noPlacesNearbyYet;

  /// Text in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Add a garage, fuel pump, parts shop, or biker cafe to help other riders.'**
  String get addGarageFuelPump;

  /// Text in places_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get addPlaceLower;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not update visibility: {e}'**
  String couldNotUpdateVisibility(Object e);

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete route?'**
  String get deleteRouteQuestion;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'This removes the saved route. The ride it came from is untouched.'**
  String get thisRemovesSavedRoute;

  /// Tooltip in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Delete route'**
  String get deleteRouteTitle;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Route not found'**
  String get routeNotFound;

  /// Label in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Turns'**
  String get turns;

  /// Label in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Ridden'**
  String get ridden;

  /// Text in route_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// Text in route_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Any rider can find and ride this route'**
  String get anyRiderCanFind;

  /// Text in route_detail_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Only you can see this route'**
  String get onlyCanSeeThis;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Start navigation'**
  String get startNavigation;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Turn by turn'**
  String get turnByTurn;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Derived from the recorded track — distances are along the route.'**
  String get derivedFromRecordedTrack;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Shared by another rider'**
  String get sharedByAnotherRider;

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'Shared by {value}'**
  String sharedBy(Object value);

  /// Text in route_detail_screen.
  ///
  /// In en, this message translates to:
  /// **'You can ride it, but only its owner can change or delete it.'**
  String get canRideItBut;

  /// SetState in route_navigation_screen.
  ///
  /// In en, this message translates to:
  /// **'Location permission is off, so turns can\'t be tracked. Enable it in Settings to navigate.'**
  String get locationPermissionOffSo;

  /// SetState in route_navigation_screen.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Turn them on to navigate.'**
  String get locationServicesOffTurn;

  /// Text in route_navigation_screen.
  ///
  /// In en, this message translates to:
  /// **'This route has no track to follow.'**
  String get thisRouteHasNo;

  /// Text in route_navigation_screen.
  ///
  /// In en, this message translates to:
  /// **'Off route — {distanceM} from the line'**
  String offRouteFromLine(Object distanceM);

  /// Label in route_navigation_screen.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// Label in route_navigation_screen.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get eta;

  /// Text in route_navigation_screen.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get routes;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'My routes'**
  String get myRoutes;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'No saved routes yet'**
  String get noSavedRoutesYet;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'No public routes yet'**
  String get noPublicRoutesYet;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Finish a ride, then tap \"Save as route\" on the share screen.'**
  String get finishRideThenTap;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'Public routes other riders save will show up here.'**
  String get publicRoutesOtherRiders;

  /// Text in routes_list_screen.
  ///
  /// In en, this message translates to:
  /// **'{distanceKm} km · ridden {timesRidden}×'**
  String routeRiddenSummary(Object distanceKm, Object timesRidden);

  /// Text in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'This ride has no track to save as a route.'**
  String get thisRideHasNo;

  /// Text in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'Route saved'**
  String get routeSaved;

  /// Text in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'Loading track…'**
  String get loadingTrack;

  /// Text in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'{distanceKm} km · {polylineCount} points'**
  String kmPoints(Object distanceKm, Object polylineCount);

  /// EditorialLabel in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'Route name'**
  String get routeName;

  /// HintText in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dhaka – Mawa morning run'**
  String get eGDhakaMawa;

  /// Validator in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'Give the route a name'**
  String get giveRouteName;

  /// HintText in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'Road surface, best time to ride, where to stop…'**
  String get roadSurfaceBestTime;

  /// Text in save_route_screen.
  ///
  /// In en, this message translates to:
  /// **'Save route'**
  String get saveRoute;

  /// Text in badges (+1 more).
  ///
  /// In en, this message translates to:
  /// **'Top speed'**
  String get topSpeed;

  /// Text in ride_sort.
  ///
  /// In en, this message translates to:
  /// **'Best score'**
  String get bestScore;

  /// Text in all_rides_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'All rides'**
  String get allRides;

  /// Text in all_rides_screen (+1 more).
  ///
  /// In en, this message translates to:
  /// **'No rides yet.'**
  String get noRidesYetDot;

  /// Text in all_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'Showing {shownCount} of {sortedCount}'**
  String showing(Object shownCount, Object sortedCount);

  /// Label in all_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'distance'**
  String get distanceLower;

  /// Label in all_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'top'**
  String get topLower;

  /// Text in all_rides_screen.
  ///
  /// In en, this message translates to:
  /// **'{hardBrakeCount} hard brakes · {rapidAccelCount} rapid accel · {highJerkCount} jerks'**
  String hardBrakesRapidAccel(
      Object hardBrakeCount, Object rapidAccelCount, Object highJerkCount);

  /// Text in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'Your Journey'**
  String get journey;

  /// Text in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'Go for a ride to start your journey.'**
  String get goRideStartJourney;

  /// Label in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'total km'**
  String get totalKm;

  /// Text in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · {rank}'**
  String level(Object level, Object rank);

  /// EditorialLabel in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'Distance over time'**
  String get distanceOverTime;

  /// EditorialLabel in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'Avg speed over time'**
  String get avgSpeedOverTime;

  /// Text in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'{earnedCount} of {badgesCount} earned'**
  String badgesEarnedCount(Object earnedCount, Object badgesCount);

  /// Label in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'avg speed'**
  String get avgSpeedLower;

  /// Label in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'top speed'**
  String get topSpeedLower;

  /// Label in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'score'**
  String get score;

  /// EditorialLabel in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'Recent rides'**
  String get recentRides;

  /// EditorialLabel in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'Your rides'**
  String get rides;

  /// Text in stats_screen.
  ///
  /// In en, this message translates to:
  /// **'{showing} of {total} shown'**
  String shown(Object showing, Object total);

  /// Label in badge_grid.
  ///
  /// In en, this message translates to:
  /// **'{family}, {earnedCount} of {badgesCount} earned'**
  String badgeFamilyEarned(
      Object family, Object earnedCount, Object badgesCount);

  /// Text in badge_grid.
  ///
  /// In en, this message translates to:
  /// **'You: {progress} {unit}'**
  String youProgress(Object progress, Object unit);

  /// Text in badge_grid.
  ///
  /// In en, this message translates to:
  /// **'Next: {def} — {progress} {unit} to go'**
  String nextGo(Object def, Object progress, Object unit);

  /// Text in badge_grid.
  ///
  /// In en, this message translates to:
  /// **'Every tier earned. Nothing left to chase here.'**
  String get everyTierEarnedNothing;

  /// Text in badge_grid.
  ///
  /// In en, this message translates to:
  /// **'Earned. {threshold}'**
  String earnedThreshold(Object threshold);

  /// Text in badge_grid.
  ///
  /// In en, this message translates to:
  /// **'{threshold} You\'re at {progress} of {threshold2} {unit}.'**
  String youreAt(
      Object threshold, Object progress, Object threshold2, Object unit);

  /// Text in ride_line_chart.
  ///
  /// In en, this message translates to:
  /// **'Not enough rides yet'**
  String get notEnoughRidesYet;

  /// Text in image_crop_screen.
  ///
  /// In en, this message translates to:
  /// **'Crop photo'**
  String get cropPhoto;

  /// Label in image_crop_screen.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// SetState in image_crop_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not open that photo.'**
  String get couldNotOpenThat;

  /// Text in image_crop_screen.
  ///
  /// In en, this message translates to:
  /// **'Could not save the cropped photo.'**
  String get couldNotSaveCropped;

  /// Text in image_crop_screen.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Text in image_crop_screen.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// SetState in bug_report_sheet.
  ///
  /// In en, this message translates to:
  /// **'Please describe the problem before sending.'**
  String get pleaseDescribeProblemBefore;

  /// Text in bug_report_sheet.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report. Please try again.'**
  String get couldNotSendReport;

  /// Text in bug_report_sheet.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened. Your UID and app version are included automatically.'**
  String get describeWhatHappenedUid;

  /// HintText in bug_report_sheet.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Messages wouldn\'t send — I got an error about permissions.\"'**
  String get eGMessagesWouldnt;

  /// Text in bug_report_sheet.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// Text in bug_report_sheet.
  ///
  /// In en, this message translates to:
  /// **'Send Report'**
  String get sendReport;

  /// Text in full_screen_route_map_screen.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get startCaps;

  /// Text in full_screen_route_map_screen.
  ///
  /// In en, this message translates to:
  /// **'FINISH'**
  String get finishCaps;

  /// Text in full_screen_route_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Waypoint #{selectedPointIndex} of {polylineCount}'**
  String waypoint(Object selectedPointIndex, Object polylineCount);

  /// Text in full_screen_route_map_screen.
  ///
  /// In en, this message translates to:
  /// **'{polylineCount} GPS points • Tap route to inspect waypoints'**
  String gpsPointsTapRoute(Object polylineCount);

  /// Text in full_screen_route_map_screen.
  ///
  /// In en, this message translates to:
  /// **'Save Route'**
  String get saveRouteTitle;

  /// Text in map_location_picker.
  ///
  /// In en, this message translates to:
  /// **'Drag map to move pin'**
  String get dragMapMovePin;

  /// Text in ride_route_map.
  ///
  /// In en, this message translates to:
  /// **'No route recorded'**
  String get noRouteRecorded;

  /// Sort chip on the All rides screen: newest first.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get sortRecent;

  /// Snackbar after importing nearby places from OpenStreetMap.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 place from OpenStreetMap} other{Imported {count} places from OpenStreetMap}}'**
  String importedPlaces(int count);

  /// Error: device has no connection.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your internet connection and try again.'**
  String get errOffline;

  /// Error: a request timed out.
  ///
  /// In en, this message translates to:
  /// **'That\'s taking too long. Check your connection and try again.'**
  String get errTimeout;

  /// Error: permission denied when reading data.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to view this.'**
  String get errNoPermission;

  /// Error: the requested item does not exist.
  ///
  /// In en, this message translates to:
  /// **'That could not be found — it may have been removed.'**
  String get errNotFound;

  /// Error: rate limit / quota exhausted.
  ///
  /// In en, this message translates to:
  /// **'Too many requests right now. Please try again in a moment.'**
  String get errTooManyRequests;

  /// Error: a required database index is missing or still building.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t ready yet. Please try again in a few minutes.'**
  String get errNotReady;

  /// Generic error when loading data fails.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong loading this. Please try again.'**
  String get errLoadGeneric;

  /// Generic error when there is no error object at all.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get errUnknown;

  /// Sign-in error: no such user.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email. Please sign up first.'**
  String get authUserNotFound;

  /// Sign-in error: wrong password.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get authWrongPassword;

  /// Sign-in error: malformed email.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get authInvalidEmail;

  /// Sign-in error: account disabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authUserDisabled;

  /// Sign-in error: email sign-in is turned off.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email is not enabled.'**
  String get authOperationNotAllowed;

  /// Sign-in error: throttled.
  ///
  /// In en, this message translates to:
  /// **'Too many login attempts. Please try again later.'**
  String get authTooManyRequests;

  /// Sign-in error: bad credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authInvalidCredential;

  /// Sign-up error: email already registered.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get authEmailInUse;

  /// Sign-up error: weak password.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 6 characters.'**
  String get authWeakPassword;

  /// Sign-in error: no network.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your internet connection.'**
  String get authNetworkFailed;

  /// Sign-in error: account uses another provider.
  ///
  /// In en, this message translates to:
  /// **'An account exists with this email but different sign-in method.'**
  String get authAccountExistsDifferent;

  /// Generic error containing 'network'.
  ///
  /// In en, this message translates to:
  /// **'Network connection failed. Please check your internet.'**
  String get errNetworkFailed;

  /// Generic error containing 'permission'.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Please check your account settings.'**
  String get errPermissionDenied;

  /// Last-resort generic error (never shows raw exception text).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// Location error: services off.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off. Enable GPS in your device settings to use this feature.'**
  String get errLocationOff;

  /// Location error: permission missing.
  ///
  /// In en, this message translates to:
  /// **'Location permission is needed for this feature. Grant it in Settings → ThrottleIQ.'**
  String get errLocationPermission;

  /// Location error: fallback.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location. Check that GPS is on and try again.'**
  String get errLocationGeneric;

  /// Sign-in error with the provider message appended.
  ///
  /// In en, this message translates to:
  /// **'Authentication error: {error}'**
  String authGeneric(String error);

  /// Place category: fuel stations.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get placeCatFuel;

  /// Place category: repair garages.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get placeCatGarage;

  /// Place category: spare-parts shops.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get placeCatParts;

  /// Place category: AI traffic cameras.
  ///
  /// In en, this message translates to:
  /// **'AI Camera'**
  String get placeCatAiCamera;

  /// Place category: police checkposts.
  ///
  /// In en, this message translates to:
  /// **'Police / Cop'**
  String get placeCatPolice;

  /// Place category: cafes and scenic stops.
  ///
  /// In en, this message translates to:
  /// **'Recreation'**
  String get placeCatRecreation;

  /// Record-screen greeting (lateNight, variant 1).
  ///
  /// In en, this message translates to:
  /// **'Late night runs, huh?'**
  String get greetLateNight1;

  /// Record-screen greeting (lateNight, variant 2).
  ///
  /// In en, this message translates to:
  /// **'The roads are yours at this hour.'**
  String get greetLateNight2;

  /// Record-screen greeting (lateNight, variant 3).
  ///
  /// In en, this message translates to:
  /// **'Can\'t sleep? Ride it off.'**
  String get greetLateNight3;

  /// Record-screen greeting (lateNight, variant 4). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Empty streets, {name}.'**
  String greetLateNight4(String name);

  /// Record-screen greeting (lateNight, variant 5).
  ///
  /// In en, this message translates to:
  /// **'Nobody out there but you.'**
  String get greetLateNight5;

  /// Record-screen greeting (earlyMorning, variant 1).
  ///
  /// In en, this message translates to:
  /// **'Beat the traffic.'**
  String get greetEarlyMorning1;

  /// Record-screen greeting (earlyMorning, variant 2).
  ///
  /// In en, this message translates to:
  /// **'Cold start, clear roads.'**
  String get greetEarlyMorning2;

  /// Record-screen greeting (earlyMorning, variant 3).
  ///
  /// In en, this message translates to:
  /// **'Sunrise miles hit different.'**
  String get greetEarlyMorning3;

  /// Record-screen greeting (earlyMorning, variant 4). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Up early, {name}?'**
  String greetEarlyMorning4(String name);

  /// Record-screen greeting (earlyMorning, variant 5).
  ///
  /// In en, this message translates to:
  /// **'First one out.'**
  String get greetEarlyMorning5;

  /// Record-screen greeting (morning, variant 1). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Morning, {name}.'**
  String greetMorning1(String name);

  /// Record-screen greeting (morning, variant 2).
  ///
  /// In en, this message translates to:
  /// **'Ready when you are.'**
  String get greetMorning2;

  /// Record-screen greeting (morning, variant 3).
  ///
  /// In en, this message translates to:
  /// **'Coffee first, then corners.'**
  String get greetMorning3;

  /// Record-screen greeting (morning, variant 4).
  ///
  /// In en, this message translates to:
  /// **'Fresh tank, fresh day.'**
  String get greetMorning4;

  /// Record-screen greeting (morning, variant 5). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Where to, {name}?'**
  String greetMorning5(String name);

  /// Record-screen greeting (afternoon, variant 1). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Afternoon, {name}.'**
  String greetAfternoon1(String name);

  /// Record-screen greeting (afternoon, variant 2).
  ///
  /// In en, this message translates to:
  /// **'Good day for it.'**
  String get greetAfternoon2;

  /// Record-screen greeting (afternoon, variant 3).
  ///
  /// In en, this message translates to:
  /// **'Sun\'s out. So are the roads.'**
  String get greetAfternoon3;

  /// Record-screen greeting (afternoon, variant 4). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Long way home, {name}?'**
  String greetAfternoon4(String name);

  /// Record-screen greeting (afternoon, variant 5).
  ///
  /// In en, this message translates to:
  /// **'Perfect time to slip away.'**
  String get greetAfternoon5;

  /// Record-screen greeting (evening, variant 1). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Evening, {name}.'**
  String greetEvening1(String name);

  /// Record-screen greeting (evening, variant 2).
  ///
  /// In en, this message translates to:
  /// **'Golden hour. Go.'**
  String get greetEvening2;

  /// Record-screen greeting (evening, variant 3). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Sunset run, {name}?'**
  String greetEvening3(String name);

  /// Record-screen greeting (evening, variant 4).
  ///
  /// In en, this message translates to:
  /// **'Clock out. Gear up.'**
  String get greetEvening4;

  /// Record-screen greeting (evening, variant 5).
  ///
  /// In en, this message translates to:
  /// **'Best light of the day.'**
  String get greetEvening5;

  /// Record-screen greeting (night, variant 1).
  ///
  /// In en, this message translates to:
  /// **'Night rider.'**
  String get greetNight1;

  /// Record-screen greeting (night, variant 2).
  ///
  /// In en, this message translates to:
  /// **'One more before bed?'**
  String get greetNight2;

  /// Record-screen greeting (night, variant 3). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Quiet roads, {name}.'**
  String greetNight3(String name);

  /// Record-screen greeting (night, variant 4).
  ///
  /// In en, this message translates to:
  /// **'Cool air, empty lanes.'**
  String get greetNight4;

  /// Record-screen greeting (night, variant 5). {name} is the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Headlights on, {name}.'**
  String greetNight5(String name);

  /// Stand-in for the rider's name in a greeting when they have none set. Lower-case; used mid-sentence.
  ///
  /// In en, this message translates to:
  /// **'rider'**
  String get greetingNameFallback;

  /// Record-screen tagline, line 1, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Your ride,'**
  String get quote0Setup;

  /// Record-screen tagline, line 1, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'smarter.'**
  String get quote0Payoff;

  /// Record-screen tagline, line 2, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Two wheels,'**
  String get quote1Setup;

  /// Record-screen tagline, line 2, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'one heartbeat.'**
  String get quote1Payoff;

  /// Record-screen tagline, line 3, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Every ride,'**
  String get quote2Setup;

  /// Record-screen tagline, line 3, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'a story worth logging.'**
  String get quote2Payoff;

  /// Record-screen tagline, line 4, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Trust the throttle,'**
  String get quote3Setup;

  /// Record-screen tagline, line 4, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'respect the road.'**
  String get quote3Payoff;

  /// Record-screen tagline, line 5, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'The road ahead'**
  String get quote4Setup;

  /// Record-screen tagline, line 5, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'is the only plan you need.'**
  String get quote4Payoff;

  /// Record-screen tagline, line 6, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Ride the wind,'**
  String get quote5Setup;

  /// Record-screen tagline, line 6, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'own the road.'**
  String get quote5Payoff;

  /// Record-screen tagline, line 7, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Smooth is fast.'**
  String get quote6Setup;

  /// Record-screen tagline, line 7, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Fast is smooth.'**
  String get quote6Payoff;

  /// Record-screen tagline, line 8, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Some roads'**
  String get quote7Setup;

  /// Record-screen tagline, line 8, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'you don\'t forget.'**
  String get quote7Payoff;

  /// Record-screen tagline, line 9, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Chase the horizon,'**
  String get quote8Setup;

  /// Record-screen tagline, line 9, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'not the redline.'**
  String get quote8Payoff;

  /// Record-screen tagline, line 10, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Miles make'**
  String get quote9Setup;

  /// Record-screen tagline, line 10, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'the machine yours.'**
  String get quote9Payoff;

  /// Record-screen tagline, line 11, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Every gear change'**
  String get quote10Setup;

  /// Record-screen tagline, line 11, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'is a decision.'**
  String get quote10Payoff;

  /// Record-screen tagline, line 12, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Ride far.'**
  String get quote11Setup;

  /// Record-screen tagline, line 12, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Ride smart.'**
  String get quote11Payoff;

  /// Record-screen tagline, line 13, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'The best rides'**
  String get quote12Setup;

  /// Record-screen tagline, line 13, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'start with no plan.'**
  String get quote12Payoff;

  /// Record-screen tagline, line 14, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Two wheels,'**
  String get quote13Setup;

  /// Record-screen tagline, line 14, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'infinite roads.'**
  String get quote13Payoff;

  /// Record-screen tagline, line 15, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Momentum is'**
  String get quote14Setup;

  /// Record-screen tagline, line 15, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'a kind of freedom.'**
  String get quote14Payoff;

  /// Record-screen tagline, line 16, setup half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'Read the road'**
  String get quote15Setup;

  /// Record-screen tagline, line 16, payoff half (joined with a space).
  ///
  /// In en, this message translates to:
  /// **'before it reads you.'**
  String get quote15Payoff;
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
