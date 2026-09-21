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
  String get brightnessSystemLabel => 'System';

  @override
  String get brightnessSystemDescription => 'Match your phone';

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
  String get themeRetroDescription => 'Blocky 70s poster, mustard & rust';

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
  String get emergencyContactsNotAlertedBanner =>
      'ThrottleIQ does not yet alert these contacts automatically.';

  @override
  String get emergencyContactsAckTitle => 'Contacts aren\'t alerted yet';

  @override
  String get emergencyContactsAckBody =>
      'ThrottleIQ saved this contact, but it can\'t send them an SMS or email after a crash yet. Until it can, tell someone your route before you ride.';

  @override
  String get emergencyContactsAckAction => 'I understand';

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
  String get exportCsvAction => 'Export CSV';

  @override
  String get exportFailedMessage => 'Export failed';

  @override
  String get telemetrySectionLabel => 'Telemetry';

  @override
  String get ridingPaceLabel => 'Avg moving speed';

  @override
  String get movingStoppedLabel => 'Moving / stopped';

  @override
  String get routeGpsDetailsLabel => 'Route GPS Details';

  @override
  String trackPointsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count track points',
      one: '1 track point',
    );
    return '$_temp0';
  }

  @override
  String get startPointLabel => 'Start';

  @override
  String get finishPointLabel => 'Finish';

  @override
  String get exploreFullRouteAction => 'Explore Full Route on Map';

  @override
  String get saveAsRouteAction => 'Save as Route';

  @override
  String get mapExpandHintLabel => 'Tap map to expand';

  @override
  String get elevationGainLabel => 'Elevation Gain';

  @override
  String get elevationLossLabel => 'Elevation Loss';

  @override
  String get elevationProfileLabel => 'Elevation Profile';

  @override
  String get speedProfileLabel => 'Speed Profile';

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
  String loggedToBikeLabel(String bikeName) {
    return 'Logged to $bikeName';
  }

  @override
  String get changeBikeSheetTitle => 'Change bike';

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
  String get safeQrShareImageAction => 'Save or share QR image';

  @override
  String get safeQrShareImageFailed => 'Couldn\'t create the QR image.';

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

  @override
  String get rideAlertHardBraking => 'Ease on the brakes';

  @override
  String get rideAlertRapidAccel => 'Smooth on the throttle';

  @override
  String get rideAlertOverspeed => 'Watch your speed';

  @override
  String get rideAlertFatigue => 'Time for a break';

  @override
  String get liveShareAgainAction => 'Share link again';

  @override
  String get liveShareStopAction => 'Stop sharing now';

  @override
  String get liveShareStopDescription =>
      'The link stops working. Your ride keeps recording.';

  @override
  String get email => 'Email';

  @override
  String get emailRequired => 'Email required';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get passwordTooShort => 'Password too short';

  @override
  String get signIn => 'Sign In';

  @override
  String get orDivider => 'or';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get noAccountPrompt => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to continue tracking your rides';

  @override
  String get yourGarage => 'Your Garage';

  @override
  String get everyBikeOwnTracked => 'Every bike you own, tracked in one place.';

  @override
  String get addUnlimitedBikesBrand =>
      'Add unlimited bikes — brand, model, year, CC';

  @override
  String get bikesPaintColorTints =>
      'Your bike\'s paint color tints the whole app';

  @override
  String get tapAnyBikeView => 'Tap any bike to view full history & details';

  @override
  String get switchActiveBikeBefore => 'Switch active bike before each ride';

  @override
  String get activeMotorcycle => 'Active Motorcycle';

  @override
  String get tintsEntireAppTheme =>
      'Tints the entire app theme and binds to your trip logs.';

  @override
  String get serviceCountdown => 'Service Countdown';

  @override
  String get realTimeMaintenanceTracker =>
      'Real-time maintenance tracker based on actual km ridden.';

  @override
  String get addSwitch => 'Add & Switch';

  @override
  String get manageMultipleBikesSwap =>
      'Manage multiple bikes and swap your active ride anytime.';

  @override
  String get startRide => 'Start a Ride';

  @override
  String get holdButtonThrottleiqDoes =>
      'Hold the button. ThrottleIQ does the rest.';

  @override
  String get holdStartRecordTab => 'Hold-to-start on the Record tab to begin';

  @override
  String get gpsSensorFusionCaptures =>
      'GPS + sensor fusion captures every moment';

  @override
  String get continuesRecordingBackground =>
      'Continues recording in the background';

  @override
  String get pausedRideSurvivesApp =>
      'A paused ride survives the app being closed';

  @override
  String get shareLiveLocationWith =>
      'Share your live location with family in real time';

  @override
  String get cockpitTelemetry => 'Cockpit Telemetry';

  @override
  String get liveGpsSpeedDistance =>
      'Live GPS speed, distance, and ride telemetry as you go.';

  @override
  String get hold1sRecord => 'Hold 1s to Record';

  @override
  String get hold1sStartStop =>
      'Hold 1s to start or stop; prevents accidental touches.';

  @override
  String get liveShare => 'Live Share';

  @override
  String get sendRevocableLinkSo =>
      'Send a revocable link so family can follow your ride.';

  @override
  String get autoTracking => 'Auto Tracking';

  @override
  String get ridesThatDetectRecord =>
      'Rides that detect and record themselves.';

  @override
  String get enableOnceSettingsAuto =>
      'Enable once in Settings → Auto-Tracking';

  @override
  String get activityRecognitionStartsRecording =>
      'Activity recognition starts recording when you ride';

  @override
  String get shortWalksSubwayTrips =>
      'Short walks and subway trips are filtered out';

  @override
  String get eachAutoDetectedRide =>
      'Each auto-detected ride appears ready to review';

  @override
  String get smartDetection => 'Smart Detection';

  @override
  String get detectsMotorcycleMovementVia =>
      'Detects motorcycle movement via IMU sensors & speed.';

  @override
  String get nonRideFilter => 'Non-Ride Filter';

  @override
  String get ignoresWalkingBusRides =>
      'Ignores walking, bus rides, and minor phone jostling.';

  @override
  String get zeroInteraction => 'Zero Interaction';

  @override
  String get runsSilentlyBackgroundReview =>
      'Runs silently in background; review rides when done.';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get neverForgetAnotherOil => 'Never forget another oil change.';

  @override
  String get alertsWhenYoureDue =>
      'Alerts when you\'re due for oil, filter, chain lube…';

  @override
  String get logServiceResetCountdown => 'Log a service to reset the countdown';

  @override
  String get addCustomIntervalsAny =>
      'Add custom intervals for any part you care about';

  @override
  String get n13ServiceItems => '13+ Service Items';

  @override
  String get trackEngineOilChain =>
      'Track engine oil, chain lube, brake fluid, coolant, and more.';

  @override
  String get dueBadges => 'Due Badges';

  @override
  String get colorCodedProgressBars =>
      'Color-coded progress bars alert you before intervals expire.';

  @override
  String get logReset => 'Log & Reset';

  @override
  String get recordMaintenanceNotesReset =>
      'Record maintenance notes and reset the interval odometer.';

  @override
  String get riderPlaces => 'Rider Places';

  @override
  String get everyGaragePumpViewpoint =>
      'Every garage, pump, and viewpoint near you.';

  @override
  String get fuelStationsRepairShops =>
      'Fuel stations, repair shops, spare parts & cafes';

  @override
  String get tapDirectionsOpensMaps =>
      'Tap Directions → opens Maps, and offers to record';

  @override
  String get addRatePlacesHelp => 'Add and rate places to help the community';

  @override
  String get n395RiderPois => '395+ Rider POIs';

  @override
  String get verifiedFuelStationsWorkshops =>
      'Verified fuel stations, workshops, parts, and rider cafes.';

  @override
  String get navigateRecord => 'Navigate & Record';

  @override
  String get opensMapsAppCan =>
      'Opens your maps app, and can record the trip alongside it.';

  @override
  String get riderReviews => 'Rider Reviews';

  @override
  String get rateOctanePurityMechanic =>
      'Rate octane purity, mechanic honesty, and parking security.';

  @override
  String get rideTogether => 'Ride Together';

  @override
  String get ridingCommunityAllOne =>
      'Your riding community, all in one place.';

  @override
  String get shareRidesFeedHome =>
      'Share rides to the feed — home location is hidden';

  @override
  String get startGroupRideWith =>
      'Start a group ride with a 6-character join code';

  @override
  String get pushTalkIntercomBluetooth =>
      'Push-to-talk intercom for your Bluetooth helmet';

  @override
  String get bikeModelForumsTalk =>
      'Bike-model forums — talk to FZ-S, Pulsar & CBR riders';

  @override
  String get directMessageAnyRider =>
      'Direct message any rider on the platform';

  @override
  String get privacyZones => 'Privacy Zones';

  @override
  String get eachRidesStartEnd =>
      'Each ride\'s start and end are clipped before it is shared.';

  @override
  String get groupPinIntercom => 'Group PIN & Intercom';

  @override
  String get liveMapTrackingBluetooth =>
      'Live map tracking and Bluetooth helmet PTT intercom.';

  @override
  String get bikeModelForums => 'Bike Model Forums';

  @override
  String get discussModsIssuesMeets =>
      'Discuss mods, issues, and meets with owners of your bike.';

  @override
  String get yourProfile => 'Your Profile';

  @override
  String get makeItYoursAdd => 'Make it yours — add a bio to stand out.';

  @override
  String get publicProfileWithStats =>
      'Public profile with your stats & shared rides';

  @override
  String get handleLetsOtherRiders =>
      'Your @handle lets other riders find and follow you';

  @override
  String get controlWhoSeesProfile =>
      'Control who sees your profile and your bikes';

  @override
  String get safeqrOfflineEmergencyMedical =>
      'SafeQR: an offline emergency medical card';

  @override
  String get riderStats => 'Rider Stats';

  @override
  String get showcaseTotalKmSafety =>
      'Showcase total km, safety score, and peak achievements.';

  @override
  String get safeqrCard => 'SafeQR Card';

  @override
  String get offlineMedicalCardEmergency =>
      'Offline medical card for emergency responders on the road.';

  @override
  String get keepUp5Contacts =>
      'Keep up to 5 contacts on file for a responder to reach.';

  @override
  String get thatUsernameTakenTry => 'That username is taken — try another.';

  @override
  String errorWithDetail(Object e) {
    return 'Error: $e';
  }

  @override
  String get whatShouldWeCall => 'What should we call you?';

  @override
  String get addFirstBike => 'Add your first bike';

  @override
  String get nameHandleSoCommunity =>
      'Your name and @handle so the community can find you.';

  @override
  String get throttleiqTracksRidesMaintenance =>
      'ThrottleIQ tracks rides and maintenance per bike.';

  @override
  String get continueAction => 'Continue →';

  @override
  String get addBikeTakeTour => 'Add bike & take the tour';

  @override
  String get backArrow => '← Back';

  @override
  String get skipNow => 'Skip for now';

  @override
  String get fullName => 'Full Name *';

  @override
  String get eGRahimHossain => 'e.g. Rahim Hossain';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get username => 'Username *';

  @override
  String get lettersNumbersUnderscore3 =>
      'Letters, numbers, underscore · 3–20 chars';

  @override
  String get n320CharactersLetters =>
      '3-20 characters: letters, numbers, underscore';

  @override
  String get brand => 'Brand *';

  @override
  String get model => 'Model *';

  @override
  String get year => 'Year';

  @override
  String get engineCc => 'Engine CC';

  @override
  String get exitDemo => 'Exit demo';

  @override
  String get yourInfo => 'Your Info';

  @override
  String get yourBike => 'Your Bike';

  @override
  String get featureTour => 'Feature Tour';

  @override
  String get createAccount => 'Create Account';

  @override
  String get back => 'Back';

  @override
  String get joinThrottleiq => 'Join ThrottleIQ';

  @override
  String get trackEveryRideRemember => 'Track every ride, remember every mile';

  @override
  String get n6Characters => '6+ characters';

  @override
  String get min6Characters => 'Min 6 characters';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get signUpWithGoogle => 'Sign up with Google';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get rideSmarterTrackDeeper => 'Ride smarter. Track deeper.';

  @override
  String guideProgress(Object slideIndex, Object totalSlides) {
    return 'GUIDE $slideIndex OF $totalSlides';
  }

  @override
  String get skipTour => 'Skip tour';

  @override
  String get showMe => 'Show me';

  @override
  String get getRiding => 'Get Riding 🏍️';

  @override
  String get gotIt => 'Got it  →';

  @override
  String get myGarage => 'My Garage';

  @override
  String get addBike => 'Add Bike';

  @override
  String get active => 'ACTIVE';

  @override
  String get n4280KmLogged => '4,280 km logged';

  @override
  String get oilFilterDue720 => 'Oil & Filter Due in 720 km';

  @override
  String get themeTint => 'Theme Tint:';

  @override
  String get gpsLocked => 'GPS LOCKED';

  @override
  String get avg52 => 'AVG 52 · ';

  @override
  String get top124 => 'TOP 124';

  @override
  String get distance => 'DISTANCE';

  @override
  String get moving31m => 'MOVING 31m';

  @override
  String get hold1sStart => 'HOLD 1s TO START';

  @override
  String get autoTrackingSettings => 'Auto-Tracking Settings';

  @override
  String get smartNonRideFilter => 'Smart Non-Ride Filter Active';

  @override
  String get walkingBusesSubwayRides =>
      'Walking, buses & subway rides automatically ignored';

  @override
  String get detectedRide => 'Detected Ride';

  @override
  String get autoSaved => 'AUTO SAVED';

  @override
  String get maintenanceSchedule => 'Maintenance Schedule';

  @override
  String get logService => '+ Log Service';

  @override
  String get engineOilFilter => 'Engine Oil & Filter';

  @override
  String get due320Km => 'Due in 320 km';

  @override
  String get chainCleanLube => 'Chain Clean & Lube';

  @override
  String get good850Km => 'Good for 850 km';

  @override
  String get brakeFluidFlush => 'Brake Fluid Flush';

  @override
  String get good2100Km => 'Good for 2,100 km';

  @override
  String get n49VerifiedPure => '★ 4.9 · Verified Pure Fuel · Open 24/7';

  @override
  String get directions => 'Directions';

  @override
  String get riderFeed => 'Rider Feed';

  @override
  String get n2hAgo => '2h ago';

  @override
  String get morningTwistiesThrough300 =>
      'Morning twisties through 300 Feet Highway!';

  @override
  String get privacyZone200mEndpoints => 'Privacy Zone: 200m Endpoints Clipped';

  @override
  String get roadCaptainDhakaMetro => 'Road Captain · Dhaka Metro';

  @override
  String get kmRidden => 'KM RIDDEN';

  @override
  String get safetyScore => 'SAFETY SCORE';

  @override
  String get safeqrOfflineMedicalCard => 'SafeQR Offline Medical Card';

  @override
  String get bloodOIceEmergency => 'Blood: O+ · ICE Emergency SOS Armed';

  @override
  String guideProgressDot(Object slideIndex, Object total) {
    return 'GUIDE · $slideIndex OF $total';
  }

  @override
  String get backTour => 'Back to Tour';

  @override
  String get next => 'Next →';

  @override
  String get closeGuide => 'Close guide';

  @override
  String get throttleiqLiveRide => 'ThrottleIQ live ride';

  @override
  String get liveSharingStopped => 'Live sharing stopped';

  @override
  String get discardThisRide => 'Discard this ride?';

  @override
  String overWillBeDeleted(Object distance, Object duration) {
    return '$distance over $duration will be deleted. This ride will not be saved to your history and cannot be recovered.';
  }

  @override
  String get keepRecording => 'Keep recording';

  @override
  String get discard => 'Discard';

  @override
  String get liveSharing => 'Live sharing on';

  @override
  String get turnShareLiveLocation => 'Turn on & share live location';

  @override
  String get distanceLabel => 'Distance';

  @override
  String get avgSpeed => 'Avg Speed';

  @override
  String get confidence => 'Confidence';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get endRide => 'End Ride';

  @override
  String get discardRide => 'Discard ride';

  @override
  String get rideKeptFromLast => 'Ride kept from last time';

  @override
  String get resumeCarryDiscardIt =>
      'Resume to carry on, or discard it to start fresh.';

  @override
  String get crashDetected => 'CRASH DETECTED';

  @override
  String get okEmergencyContactsWill =>
      'Are you OK? Your emergency contacts will be notified when the timer ends.';

  @override
  String get seconds => 'seconds';

  @override
  String get imOk => 'I\'M OK';

  @override
  String get brakeCaps => 'BRAKE';

  @override
  String get accelCaps => 'ACCEL';

  @override
  String get turnOnLocation => 'Turn on Location';

  @override
  String get openAppSettings => 'Open App Settings';

  @override
  String get reportProblem => 'Report a Problem';

  @override
  String get noBikeYet => 'No bike yet';

  @override
  String get addBikeRideThrottleiq =>
      'Add the bike you ride and ThrottleIQ can start tracking it.';

  @override
  String get addABike => 'Add a bike';

  @override
  String get backgroundLocation => 'Background location';

  @override
  String get backgroundLocationRationale =>
      'ThrottleIQ records your route, speed, and distance using your location while a ride is active — including while your phone is locked or in a pocket, so the ride isn\'t cut short. The next screen will ask for \"Allow all the time\" location access. Location is only used to record your ride, and tracking stops the moment you end it.';

  @override
  String get notNow => 'Not now';

  @override
  String get continueLabel => 'Continue';

  @override
  String get turnOnCaps => 'TURN ON';

  @override
  String get settingsCaps => 'SETTINGS';

  @override
  String get slideStartRide => 'Slide to start ride';

  @override
  String get close => 'Close';

  @override
  String get fetchingRoute => 'Fetching route…';

  @override
  String get routeNotAvailable => 'Route not available';

  @override
  String get zoomIn => 'Zoom In';

  @override
  String get zoomOut => 'Zoom Out';

  @override
  String get recenterRoute => 'Recenter Route';

  @override
  String get fullscreenMap => 'Fullscreen Map';

  @override
  String get rideRecorded => 'Ride Recorded';

  @override
  String get unknownDate => 'Unknown date';

  @override
  String get savedCaps => 'SAVED';

  @override
  String get discardedCaps => 'DISCARDED';

  @override
  String get briefTripNotClassified => 'Brief trip not classified as ride';

  @override
  String get activeHours => 'Active hours';

  @override
  String onlyWatchingRidesBetween(Object startMinutes, Object endMinutes) {
    return 'Only watching for rides between $startMinutes and $endMinutes.';
  }

  @override
  String get watchingRidesAllDay => 'Watching for rides all day.';

  @override
  String get fromLabel => 'From';

  @override
  String get untilLabel => 'Until';

  @override
  String get startTimeMustBe => 'The start time must be before the end time.';

  @override
  String get endRideQuestion => 'End ride?';

  @override
  String get rideWillBeSaved => 'Your ride will be saved.';

  @override
  String get shareRideAfterSaving => 'Share ride after saving';

  @override
  String get keepRiding => 'Keep riding';

  @override
  String get endRidePressHold => 'End ride. Press and hold.';

  @override
  String get keepHolding => 'Keep holding…';

  @override
  String get holdEndRide => 'Hold to end ride';

  @override
  String get startRidePressHold => 'Start ride. Press and hold.';

  @override
  String get goCaps => 'GO';

  @override
  String get holdCaps => 'HOLD';

  @override
  String get recordingNotificationTextUser =>
      'ThrottleIQ is recording your ride in the background';

  @override
  String get recordingNotificationTextAuto =>
      'ThrottleIQ detected a ride and is recording it';

  @override
  String get rideRecordingActive => 'Ride Recording Active';

  @override
  String get rideDetected => 'Ride Detected';

  @override
  String get recordingLocationOff =>
      'Location is turned off. Turn on Location Services to start a ride.';

  @override
  String get recordingPermissionDenied =>
      'ThrottleIQ needs location permission to track your ride. Grant it in Settings.';

  @override
  String get addBikeBeforeRecording =>
      'Please add a bike before recording a ride.';

  @override
  String get aRider => 'A rider';

  @override
  String livePositionsUnavailable(Object e) {
    return 'Live positions unavailable: $e';
  }

  @override
  String get locationPermissionOffGroup =>
      'Location permission is off — the group can\'t see you. You can still see them.';

  @override
  String locationUnavailable(Object e) {
    return 'Location unavailable: $e';
  }

  @override
  String get leaveGroupRide => 'Leave group ride?';

  @override
  String get othersStopSeeingPosition =>
      'The others stop seeing your position. Your own ride recording keeps running — end it from the ride screen.';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String couldntLeave(Object e) {
    return 'Couldn\'t leave: $e';
  }

  @override
  String get microphoneAccessOffCan =>
      'Microphone access is off — you can still hear the group.';

  @override
  String couldntStartRecording(Object e) {
    return 'Couldn\'t start recording: $e';
  }

  @override
  String couldntSendVoiceNote(Object e) {
    return 'Couldn\'t send voice note: $e';
  }

  @override
  String get groupRide => 'Group ride';

  @override
  String get thisGroupRideNo => 'This group ride no longer exists.';

  @override
  String get recordingReleaseSend => 'Recording — release to send';

  @override
  String playing(Object note) {
    return 'Playing $note…';
  }

  @override
  String get holdTalk => 'Hold to talk';

  @override
  String get unmuteVoiceNotes => 'Unmute voice notes';

  @override
  String get muteVoiceNotes => 'Mute voice notes';

  @override
  String get nobodyThisRideYet => 'Nobody is on this ride yet.';

  @override
  String ridingJoined(Object joinedCount) {
    return 'Riding — $joinedCount';
  }

  @override
  String invitedWaiting(Object pendingCount) {
    return 'Invited — $pendingCount waiting';
  }

  @override
  String get hasntJoinedYet => 'Hasn\'t joined yet';

  @override
  String you(Object userName) {
    return '$userName (you)';
  }

  @override
  String get waitingFirstPosition => 'Waiting for the first position…';

  @override
  String get deleteSharedRide => 'Delete shared ride?';

  @override
  String get thisRemovesItFrom =>
      'This removes it from the feed for everyone. Your local ride history is unaffected.';

  @override
  String get delete => 'Delete';

  @override
  String get mySharedRides => 'My Shared Rides';

  @override
  String get haventSharedAnyRides => 'You haven\'t shared any rides yet';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String couldntJoinRide(Object e) {
    return 'Couldn\'t join the ride: $e';
  }

  @override
  String tapJoin(Object relativeTime) {
    return '$relativeTime · tap to join';
  }

  @override
  String get anyoneThrottleiq => 'Anyone on ThrottleIQ';

  @override
  String get peopleWhoFollow => 'People who follow you';

  @override
  String get ridersFollowEachOther => 'Riders you follow each other';

  @override
  String canAddUpPhotos(Object maxRidePhotos) {
    return 'You can add up to $maxRidePhotos photos. Remove one to add another.';
  }

  @override
  String onlyPhotosPerRide(Object maxRidePhotos, Object remaining) {
    return 'Only $maxRidePhotos photos per ride — kept the first $remaining.';
  }

  @override
  String get rideShared => 'Ride shared';

  @override
  String get savedWellPostIt =>
      'Saved — we\'ll post it when you\'re back online';

  @override
  String failedShareRide(Object e) {
    return 'Failed to share ride: $e';
  }

  @override
  String addUpRideBike(Object maxRidePhotos) {
    return 'Add up to $maxRidePhotos ride or bike photos';
  }

  @override
  String get shareRide => 'Share ride';

  @override
  String get saySomethingAboutThis => 'Say something about this ride';

  @override
  String get photosOptional => 'Photos (optional)';

  @override
  String get whoCanSeeThis => 'Who can see this';

  @override
  String get saveAsRoute => 'Save as route';

  @override
  String get routeSavedMyRoutes => 'Route saved to My Routes!';

  @override
  String failedPostComment(Object e) {
    return 'Failed to post comment: $e';
  }

  @override
  String voteFailed(Object e) {
    return 'Vote failed: $e';
  }

  @override
  String couldNotSaveRoute(Object e) {
    return 'Could not save route: $e';
  }

  @override
  String get rideDetails => 'Ride Details';

  @override
  String get rideNotFoundRemoved => 'Ride not found or removed';

  @override
  String get reportRide => 'Report Ride';

  @override
  String get noGpsTrackAvailable => 'No GPS track available for this ride';

  @override
  String get speedPerformanceDetails => 'Speed & Performance Details';

  @override
  String get maxSpeed => 'Max Speed';

  @override
  String get duration => 'Duration';

  @override
  String get ridingPace => 'Riding Pace';

  @override
  String trackPoints(Object polylineCount) {
    return '$polylineCount track points';
  }

  @override
  String get startColon => 'Start: ';

  @override
  String get finishColon => 'Finish: ';

  @override
  String get ridePhotos => 'Ride Photos';

  @override
  String get upvote => 'Upvote';

  @override
  String get downvote => 'Downvote';

  @override
  String commentsCount(Object comments) {
    return '$comments comments';
  }

  @override
  String get noCommentsYetBe => 'No comments yet. Be the first to comment!';

  @override
  String get addComment => 'Add a comment...';

  @override
  String get send => 'Send';

  @override
  String get searchRidersForums => 'Search riders and forums';

  @override
  String get messages => 'Messages';

  @override
  String get feed => 'Feed';

  @override
  String get forums => 'Forums';

  @override
  String nothingFoundTryUsername(Object query) {
    return 'Nothing found for \"$query\".\nTry a @username, an email, or a forum name.';
  }

  @override
  String couldntSearchRiders(Object error) {
    return 'Couldn\'t search riders: $error';
  }

  @override
  String get noRidersMatchThat => 'No riders match that.';

  @override
  String couldntSearchForums(Object error) {
    return 'Couldn\'t search forums: $error';
  }

  @override
  String get noForumsMatchThat => 'No forums match that.';

  @override
  String followersPosts(Object followerCount, Object postCount) {
    return '$followerCount followers · $postCount posts';
  }

  @override
  String get nothingFromRidersYet => 'Nothing from your riders yet';

  @override
  String get noRidesYet => 'No rides yet';

  @override
  String get searchRidersAboveFollow =>
      'Search for riders above and follow them to fill this in.';

  @override
  String get shareRideFromIts =>
      'Share a ride from its summary screen to get things started.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get youreAllCaughtUp => 'You\'re all caught up';

  @override
  String get details => 'Details';

  @override
  String get noCommentsYet => 'No comments yet';

  @override
  String get following => 'Following';

  @override
  String get follow => 'Follow';

  @override
  String get rideWithFriends => 'Ride with friends';

  @override
  String selectedCount(Object selectedCount, Object maxGroupRideFriends) {
    return '$selectedCount/$maxGroupRideFriends selected';
  }

  @override
  String pickRidersRideStarts(
      Object minGroupRideFriends, Object maxGroupRideFriends) {
    return 'Pick $minGroupRideFriends–$maxGroupRideFriends riders. Your ride starts recording right away; they join from their notifications.';
  }

  @override
  String get usernameEmail => '@username or email';

  @override
  String get startGroupRide => 'Start group ride';

  @override
  String startGroupRideWithCount(Object selectedCount) {
    return 'Start group ride with $selectedCount';
  }

  @override
  String get searchByUsernameEmail => 'Search by @username or email';

  @override
  String get noRidersFound => 'No riders found';

  @override
  String inviterGroupRide(Object inviterName) {
    return '$inviterName\'s group ride';
  }

  @override
  String couldntStartGroupRide(Object e) {
    return 'Couldn\'t start the group ride: $e';
  }

  @override
  String get signCreateForum => 'Sign in to create a forum.';

  @override
  String couldNotCreateForum(Object e) {
    return 'Could not create the forum: $e';
  }

  @override
  String get createForum => 'Create a forum';

  @override
  String get eGSundayBreakfast => 'e.g. Sunday Breakfast Rides';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get whatsThisForumAbout => 'What\'s this forum about?';

  @override
  String get youllBeAbleModerate =>
      'You\'ll be able to moderate posts here and add other riders as maintainers.';

  @override
  String get create => 'Create';

  @override
  String failedPostReply(Object e) {
    return 'Failed to post reply: $e';
  }

  @override
  String get post => 'Post';

  @override
  String get postNotFound => 'Post not found';

  @override
  String get noRepliesYetBe => 'No replies yet — be the first to help out.';

  @override
  String get writeReply => 'Write a reply...';

  @override
  String get forum => 'Forum';

  @override
  String get unfollow => 'Unfollow';

  @override
  String get manageMaintainers => 'Manage maintainers';

  @override
  String get newPost => 'New post';

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get beFirstAskQuestion =>
      'Be the first to ask a question or share something.';

  @override
  String get title => 'Title';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get whatsGoing => 'What\'s going on?';

  @override
  String get saySomethingBeforePosting => 'Say something before posting';

  @override
  String get couldntRecordVoteCheck =>
      'Couldn\'t record your vote — check your connection and try again.';

  @override
  String get deletePostQuestion => 'Delete post?';

  @override
  String get thisRemovesPostIts =>
      'This removes the post and its replies from the forum. It cannot be undone.';

  @override
  String couldNotDelete(Object e) {
    return 'Could not delete: $e';
  }

  @override
  String get deletePost => 'Delete post';

  @override
  String get reportPost => 'Report Post';

  @override
  String fromUser(Object displayName) {
    return 'from $displayName';
  }

  @override
  String couldNotUpdateMaintainers(Object e) {
    return 'Could not update maintainers: $e';
  }

  @override
  String get maintainers => 'Maintainers';

  @override
  String get maintainersCanDeletePosts =>
      'Maintainers can delete posts and replies in this forum.';

  @override
  String get noMaintainersYet => 'No maintainers yet.';

  @override
  String get remove => 'Remove';

  @override
  String get addByRiderUid => 'Add by rider UID';

  @override
  String couldNotOpenForum(Object e) {
    return 'Could not open forum: $e';
  }

  @override
  String get yourBikes => 'Your bikes';

  @override
  String get addBikeGarageSee =>
      'Add a bike to your garage to see its forum here.';

  @override
  String get riderForums => 'Rider forums';

  @override
  String get noRiderMadeForums =>
      'No rider-made forums yet. Create the first one.';

  @override
  String get findForum => 'Find a forum';

  @override
  String get searchBrandEG => 'Search a brand, e.g. Yamaha';

  @override
  String get searchForums => 'Search forums';

  @override
  String get brands => 'Brands';

  @override
  String get topics => 'Topics';

  @override
  String postsFollowers(Object postCount, Object followerCount) {
    return '$postCount posts · $followerCount followers';
  }

  @override
  String get notificationSettings => 'Notification settings';

  @override
  String get newMessage => 'New message';

  @override
  String get newMessageTitle => 'New Message';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get startConversation => 'Start a Conversation';

  @override
  String get loading => 'Loading...';

  @override
  String get sayHi => 'Say hi!';

  @override
  String get searchRiderByUsername => 'Search rider by @username or email...';

  @override
  String noRidersFoundFor(Object text) {
    return 'No riders found for \"$text\"';
  }

  @override
  String get retry => 'Retry';

  @override
  String get chat => 'Chat';

  @override
  String get cantMessageThisRider => 'You can\'t message this rider';

  @override
  String get messageHint => 'Message...';

  @override
  String get spamMisleading => 'Spam or misleading';

  @override
  String get harassmentBullying => 'Harassment or bullying';

  @override
  String get hateSpeech => 'Hate speech';

  @override
  String get inappropriateContent => 'Inappropriate content';

  @override
  String get reportSubmittedSuccessfullyWe =>
      'Report submitted successfully. We will review it shortly.';

  @override
  String failedSubmitReport(Object e) {
    return 'Failed to submit report: $e';
  }

  @override
  String get report => 'Report';

  @override
  String get whyReportingThis => 'Why are you reporting this?';

  @override
  String get additionalDetailsOptional => 'Additional details (optional)';

  @override
  String get submitReport => 'Submit Report';

  @override
  String get audiencePublic => 'Public';

  @override
  String get audienceFollowers => 'Followers';

  @override
  String get audienceMutual => 'Mutual';

  @override
  String get selfHarm => 'Self-harm';

  @override
  String get otherReason => 'Other';

  @override
  String followMyRideLive(String url) {
    return 'Follow my ride live: $url';
  }

  @override
  String get logServiceTitle => 'Log Service';

  @override
  String get serviceType => 'Service Type';

  @override
  String get whatDidService => 'What did you service? *';

  @override
  String get eGRadiatorFlush => 'e.g. Radiator flush';

  @override
  String get nameService => 'Name the service';

  @override
  String get odometerKm => 'Odometer (km) *';

  @override
  String get requiredField => 'Required';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get costOptional => 'Cost (optional)';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String configuredSpec(Object specNote) {
    return 'Configured spec: $specNote';
  }

  @override
  String get eGOctane95 => 'e.g. Octane 95, 12L fill-up, Jamuna oil...';

  @override
  String get eGUsedMotul => 'e.g. Used Motul 10W40...';

  @override
  String insertSpec(Object specNote) {
    return 'Insert spec: $specNote';
  }

  @override
  String get saveServiceLog => 'Save Service Log';

  @override
  String get yourMotorcycle => 'Your Motorcycle';

  @override
  String get setupMaintenance => 'Setup Maintenance';

  @override
  String get editTrackedChecks => 'Edit Tracked Checks';

  @override
  String get skip => 'Skip';

  @override
  String whatWouldLikeTrack(Object bikeName) {
    return 'What would you like to track for $bikeName?';
  }

  @override
  String get selectComponentsWantThrottleiq =>
      'Select the components you want ThrottleIQ to monitor. We will calculate wear based on your odometer and notify you before services are due.';

  @override
  String get recommended => 'Recommended';

  @override
  String get selectAll => 'Select All';

  @override
  String get clear => 'Clear';

  @override
  String trackChecks(Object enabledCount) {
    return 'Track $enabledCount Checks';
  }

  @override
  String get savePreferences => 'Save Preferences';

  @override
  String activeInCategory(Object activeInCategory, Object categoryItemsCount) {
    return '$activeInCategory of $categoryItemsCount active';
  }

  @override
  String get noActiveBike => 'No active bike';

  @override
  String get addMotorcycleGarageTrack =>
      'Add a motorcycle to your garage to track maintenance.';

  @override
  String get syncOdo => 'Sync Odo';

  @override
  String get customize => 'Customize';

  @override
  String get log => 'Log';

  @override
  String get resetServiceLog => 'Reset service log';

  @override
  String get trackedChecks => 'Tracked checks';

  @override
  String monitored(Object remindersCount) {
    return '$remindersCount monitored';
  }

  @override
  String filterAll(Object remindersCount) {
    return 'All ($remindersCount)';
  }

  @override
  String filterAttention(Object attentionCount) {
    return 'Attention ($attentionCount)';
  }

  @override
  String filterOk(Object okCount) {
    return 'OK ($okCount)';
  }

  @override
  String get noChecksTrackedYet =>
      'No checks tracked yet. Tap \"Customize\" above to select checks.';

  @override
  String get noChecksMatchingThis => 'No checks matching this filter.';

  @override
  String get serviceHistory => 'Service history';

  @override
  String total(Object totalCost) {
    return 'Total: ৳$totalCost';
  }

  @override
  String get noServiceRecordsLogged => 'No service records logged yet.';

  @override
  String get whenServiceBikeLog =>
      'When you service your bike, log it here to reset intervals.';

  @override
  String get switchBike => 'Switch bike';

  @override
  String get switchAction => 'Switch';

  @override
  String get immediateMaintenanceAttentionRecommended =>
      'Immediate maintenance attention recommended';

  @override
  String get upcomingScheduledMaintenance => 'Upcoming scheduled maintenance';

  @override
  String get allSystemsNominal => 'All Systems Nominal';

  @override
  String allTrackedComponentsGood(Object total) {
    return 'All $total tracked components in good health';
  }

  @override
  String get dueSoonTitle => 'Due Soon';

  @override
  String get whatWouldLikeMaintain => 'What would you like to maintain?';

  @override
  String notEveryoneWantsTrack(Object displayName) {
    return 'Not everyone wants to track everything. Pick the items you care about for $displayName, or tap to edit intervals and add specs (oil brand, tyre dates/sizes):';
  }

  @override
  String get essentials4 => 'Essentials (4)';

  @override
  String get all8Items => 'All 8 items';

  @override
  String get savingPreferences => 'Saving Preferences...';

  @override
  String startTrackingItems(Object enabledCount) {
    return 'Start Tracking ($enabledCount Items)';
  }

  @override
  String get seeAll20Checks => 'See all 20+ checks & advanced setup';

  @override
  String get dueSoon => 'Due soon';

  @override
  String intervalEvery(Object imperial) {
    return 'Every $imperial';
  }

  @override
  String lastDone(Object lastServiceDate) {
    return 'Last done: $lastServiceDate';
  }

  @override
  String get noPreviousServiceRecorded => 'No previous service recorded';

  @override
  String get edit => 'Edit';

  @override
  String get deleteLog => 'Delete Log';

  @override
  String sureWantDeleteThis(Object displayLabel) {
    return 'Are you sure you want to delete this $displayLabel record?';
  }

  @override
  String get trackDashboard => 'Track on Dashboard';

  @override
  String get calculateWearMonitorInterval =>
      'Calculate wear and monitor interval';

  @override
  String get serviceInterval => 'Service Interval';

  @override
  String get intervalDistanceKm => 'Interval Distance (km)';

  @override
  String get enterPositiveNumber => 'Enter a positive number';

  @override
  String get specificationsExtraInfo => 'Specifications & Extra Info';

  @override
  String get optionalText => 'Optional text';

  @override
  String get specsOilGradeTyre => 'Specs (oil grade, tyre sizes & dates...)';

  @override
  String get visibleMaintenanceCardQuick =>
      'Visible on your maintenance card for quick reference.';

  @override
  String odometerSyncedKm(Object newKm) {
    return 'Odometer synced to $newKm km!';
  }

  @override
  String get syncOdometer => 'Sync Odometer';

  @override
  String alignThrottleiqWith(Object displayName) {
    return 'Align ThrottleIQ with $displayName';
  }

  @override
  String get rodeOfflineWithoutPhone =>
      'Rode offline or without phone tracking? Take a photo of your bike\'s dashboard/speedometer cluster or enter the current reading below.';

  @override
  String get scanningInstrumentCluster => 'Scanning instrument cluster...';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get fromPhotos => 'From Photos';

  @override
  String get currentAppOdometer => 'Current App Odometer:';

  @override
  String get physicalInstrumentClusterReading =>
      'Physical Instrument Cluster Reading *';

  @override
  String get enterValidPositiveNumber => 'Enter valid positive number';

  @override
  String kmAddedOfflineRiding(Object delta) {
    return '+$delta km added (offline riding accounted for)';
  }

  @override
  String kmReductionCalibratingBaseline(Object delta) {
    return '$delta km reduction (calibrating baseline)';
  }

  @override
  String get confirmSyncOdometer => 'Confirm & Sync Odometer';

  @override
  String get resetSelectedItems => 'Reset selected items?';

  @override
  String thisLogsAsServiced(Object label) {
    return 'This logs \"$label\" as serviced today at the bike\'s current odometer, resetting its due date. Past history is kept.';
  }

  @override
  String thisLogsItemsAs(Object selectedCount) {
    return 'This logs $selectedCount items as serviced today at the bike\'s current odometer, resetting their due dates. Past history is kept.';
  }

  @override
  String get reset => 'Reset';

  @override
  String get n1ItemResetServiced => '1 item reset to serviced today.';

  @override
  String itemsResetServicedToday(Object count) {
    return '$count items reset to serviced today.';
  }

  @override
  String get resetServiceLogTitle => 'Reset Service Log';

  @override
  String tickWhatJustServiced(Object displayName) {
    return 'Tick what you just serviced on $displayName';
  }

  @override
  String get selectedItemsLoggedAs =>
      'Selected items are logged as serviced today at the current odometer, resetting their due date. Nothing is deleted.';

  @override
  String get noTrackedChecksYet =>
      'No tracked checks yet. Set some up under \"Customize\" first.';

  @override
  String selectedOfTotal(Object selectedCount, Object remindersCount) {
    return '$selectedCount of $remindersCount selected';
  }

  @override
  String get selectItemsReset => 'Select items to reset';

  @override
  String lastDoneKmAgo(Object kmSinceService) {
    return 'Last done $kmSinceService km ago';
  }

  @override
  String get cropBikePhoto => 'Crop bike photo';

  @override
  String get bikeAdded => 'Bike added.';

  @override
  String get setServiceIntervals => 'Set service intervals';

  @override
  String get editBike => 'Edit Bike';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get crop => 'Crop';

  @override
  String get replace => 'Replace';

  @override
  String get odometerReadingKm => 'Odometer reading (km)';

  @override
  String get bikeColor => 'Bike color';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get bikeNotFound => 'Bike not found';

  @override
  String archived(Object displayName) {
    return '$displayName (archived)';
  }

  @override
  String get discussThisBike => 'Discuss this bike';

  @override
  String get unarchiveBike => 'Unarchive bike';

  @override
  String get archiveDeleteBike => 'Archive or delete bike';

  @override
  String get totalDistance => 'Total Distance';

  @override
  String get totalRides => 'Total Rides';

  @override
  String get odometer => 'Odometer';

  @override
  String get engine => 'Engine';

  @override
  String get rideHistory => 'Ride History';

  @override
  String get noRidesYetThis => 'No rides yet for this bike';

  @override
  String removeBikeQuestion(Object displayName) {
    return 'Remove $displayName?';
  }

  @override
  String get archivingHidesThisBike =>
      'Archiving hides this bike from your garage and bike pickers. Its rides stay in your history and stats, and you can unarchive it any time.';

  @override
  String get deleteBikeAllIts => 'Delete bike and all its rides';

  @override
  String get archiveBikeKeepRides => 'Archive bike (keep rides)';

  @override
  String couldNotArchiveThis(Object e) {
    return 'Could not archive this bike: $e';
  }

  @override
  String couldNotDeleteThis(Object e) {
    return 'Could not delete this bike: $e';
  }

  @override
  String get bikeBackGarage => 'Bike is back in your garage';

  @override
  String couldNotUnarchiveThis(Object e) {
    return 'Could not unarchive this bike: $e';
  }

  @override
  String get deleteBikeQuestion => 'Delete bike and all its rides?';

  @override
  String get usingDefaultServiceIntervals => 'Using default service intervals';

  @override
  String get serviceMaintenance => 'Service & maintenance';

  @override
  String nextSummary(Object summary) {
    return 'Next: $summary';
  }

  @override
  String get intervals => 'Intervals';

  @override
  String get viewAll => 'View all';

  @override
  String get yourBikesTitle => 'Your Bikes';

  @override
  String get viewProfile => 'View profile';

  @override
  String get myPlaces => 'My Places';

  @override
  String get noBikesYet => 'No bikes yet';

  @override
  String get addFirstBikeGet => 'Add your first bike to get started';

  @override
  String get setActive => 'Set active';

  @override
  String get totalLower => 'total';

  @override
  String get ridesLower => 'rides';

  @override
  String get lastRide => 'last ride';

  @override
  String archivedBikes(Object bikesCount) {
    return 'Archived bikes ($bikesCount)';
  }

  @override
  String ridesAndDistance(Object rideCount, Object totalDistanceM) {
    return '$rideCount rides · $totalDistanceM';
  }

  @override
  String get unarchive => 'Unarchive';

  @override
  String get myFollowers => 'My followers';

  @override
  String get onlyMe => 'Only me';

  @override
  String get blockedUsers => 'Blocked Users';

  @override
  String get noBlockedUsers => 'No blocked users';

  @override
  String get errorLoadingUser => 'Error loading user';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get unblock => 'Unblock';

  @override
  String couldNotSaveProfile(Object e) {
    return 'Could not save profile: $e';
  }

  @override
  String get editProfile => 'Edit profile';

  @override
  String get displayName => 'Display name';

  @override
  String get nickname => 'Nickname';

  @override
  String get shownCardsFeed => 'Shown on cards & feed';

  @override
  String get usernameField => 'Username';

  @override
  String get n320LettersNumbers => '3-20 letters, numbers or underscore';

  @override
  String get bio => 'Bio';

  @override
  String get whoCanSeeProfile => 'Who can see my profile';

  @override
  String get everyone => 'Everyone';

  @override
  String get mutuals => 'Mutuals';

  @override
  String get whoCanSeeBikes => 'Who can see my bikes';

  @override
  String get garageProfileSeparateFrom =>
      'Your garage on your profile. Separate from who can see the profile itself.';

  @override
  String get tellRidersAboutYourself => 'Tell riders about yourself';

  @override
  String get goodBioGetsMore => 'A good bio gets you more followers.';

  @override
  String get eGFzS =>
      'e.g. \"FZ-S rider from Dhaka. Weekend tourer. Coffee & corners.\"';

  @override
  String get saveBio => 'Save bio';

  @override
  String get privacySafety => 'Privacy & Safety';

  @override
  String get manageAccountsHaveBlocked => 'Manage accounts you have blocked';

  @override
  String get seeDemoFeatureTour => 'See Demo & Feature Tour';

  @override
  String get replayInteractiveFeatureGuides =>
      'Replay interactive feature guides and safety walkthrough';

  @override
  String get sendBugReport => 'Send Bug Report';

  @override
  String get somethingBrokenLetTeam => 'Something broken? Let the team know';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountQuestion => 'Delete Account?';

  @override
  String get thisActionIrreversibleAll =>
      'This action is irreversible. All your recorded rides, bike profiles, stats, and personal data will be permanently deleted.';

  @override
  String get deletePermanently => 'Delete Permanently';

  @override
  String get deletingAccount => 'Deleting account...';

  @override
  String errorDeletingAccount(Object e) {
    return 'Error deleting account: $e';
  }

  @override
  String get syncIssues => 'Sync issues';

  @override
  String get n1UpdateCouldntBe => '1 update couldn\'t be sent';

  @override
  String updatesCouldntBeSent(Object count) {
    return '$count updates couldn\'t be sent';
  }

  @override
  String get rideShare => 'Ride share';

  @override
  String get endingLiveShare => 'Ending a live share';

  @override
  String get maintenanceLog => 'Maintenance log';

  @override
  String get cloudUpdate => 'Cloud update';

  @override
  String get everythingSynced => 'Everything is synced';

  @override
  String get synced => 'Synced';

  @override
  String get couldntSyncYetWell =>
      'Couldn\'t sync yet. We\'ll keep trying in the background.';

  @override
  String get discardThisUpdate => 'Discard this update?';

  @override
  String get itWontBeSent => 'It won\'t be sent. This can\'t be undone.';

  @override
  String get signViewProfile => 'Sign in to view your profile';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get reportUser => 'Report User';

  @override
  String get blockUser => 'Block User';

  @override
  String get tapEditFinishSetting =>
      'Tap Edit to finish setting up your profile';

  @override
  String get riderNotFound => 'Rider not found';

  @override
  String ridingWithUsSince(Object createdAt) {
    return 'Riding with us since $createdAt';
  }

  @override
  String get followersLabel => 'followers';

  @override
  String get followingLabel => 'following';

  @override
  String get message => 'Message';

  @override
  String get totalDistanceLower => 'total distance';

  @override
  String get ridesLogged => 'rides logged';

  @override
  String get badges => 'Badges';

  @override
  String get noBadgesEarnedYet => 'No badges earned yet';

  @override
  String get myGarageLower => 'My garage';

  @override
  String get garage => 'Garage';

  @override
  String get whoCanSeeBikesChangeUnderEdit =>
      'Who can see my bikes — change this under Edit';

  @override
  String get thisProfilePrivate => 'This profile is private';

  @override
  String get youreOffline => 'You\'re offline';

  @override
  String get couldntLoadProfile => 'Couldn\'t load profile';

  @override
  String resetItemsButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reset $count Items',
      one: 'Reset 1 Item',
    );
    return '$_temp0';
  }

  @override
  String deleteBikeConfirmBody(int rides, String expected) {
    String _temp0 = intl.Intl.pluralLogic(
      rides,
      locale: localeName,
      other: '$rides rides',
      one: '1 ride',
    );
    return 'This permanently deletes $_temp0, their routes and this bike\'s maintenance log, on this phone and in the cloud. Type \"$expected\" to confirm.';
  }

  @override
  String get svcTypeOilChange => 'Oil Change';

  @override
  String get svcTypeAirFilter => 'Air Filter';

  @override
  String get svcTypeChain => 'Chain Lube';

  @override
  String get svcTypeTire => 'Tire Check';

  @override
  String get svcTypeRadiatorCoolant => 'Radiator / Coolant';

  @override
  String get svcTypeFrontDiscPads => 'Front Disc Pads';

  @override
  String get svcTypeRearDrumPads => 'Rear Drum Pads';

  @override
  String get svcTypeBrakeFluid => 'Brake Fluid';

  @override
  String get svcTypeSparkPlug => 'Spark Plug';

  @override
  String get svcTypeBattery => 'Battery';

  @override
  String get svcTypeValveClearance => 'Valve Clearance';

  @override
  String get svcTypeClutchCable => 'Clutch Cable';

  @override
  String get svcTypeSuspension => 'Suspension';

  @override
  String get svcTypeOilFilter => 'Oil Filter';

  @override
  String get svcTypeChainTension => 'Chain Slack & Tension';

  @override
  String get svcTypeBrakeRotors => 'Brake Rotors / Discs';

  @override
  String get svcTypeForkSeals => 'Fork Oil & Seals';

  @override
  String get svcTypeWheelBearings => 'Wheel Bearings';

  @override
  String get svcTypeDriveBelt => 'Drive Belt';

  @override
  String get svcTypeThrottleCables => 'Throttle & Cables';

  @override
  String get svcTypeFuel => 'Fuel';

  @override
  String get svcTypeCustom => 'Custom';

  @override
  String get svcDescOilChange =>
      'Drain engine oil & replace with fresh lubricant.';

  @override
  String get svcDescOilFilter =>
      'Replace oil filter element to prevent contaminant buildup.';

  @override
  String get svcDescAirFilter =>
      'Clean or replace intake filter for optimal airflow.';

  @override
  String get svcDescChain =>
      'Clean road grime & apply chain lube to drive chain.';

  @override
  String get svcDescChainTension =>
      'Check drive chain slack & align rear axle.';

  @override
  String get svcDescTire => 'Inspect tire pressures, tread wear & dry rot.';

  @override
  String get svcDescRadiatorCoolant =>
      'Flush and refill radiator coolant fluid.';

  @override
  String get svcDescFrontDiscPads =>
      'Check front brake pad friction material thickness.';

  @override
  String get svcDescRearDrumPads =>
      'Inspect rear brake pads or drum brake shoes.';

  @override
  String get svcDescBrakeFluid =>
      'Bleed & replenish hydraulic DOT brake fluid.';

  @override
  String get svcDescSparkPlug =>
      'Inspect electrode gap or replace spark plugs.';

  @override
  String get svcDescBattery =>
      'Test terminal voltage, connections & charge state.';

  @override
  String get svcDescValveClearance =>
      'Measure & adjust intake / exhaust valve clearances.';

  @override
  String get svcDescClutchCable => 'Check lever free-play & lube clutch cable.';

  @override
  String get svcDescThrottleCables =>
      'Inspect throttle play, snap-back & lube cables.';

  @override
  String get svcDescSuspension =>
      'Inspect rear shock damping & linkage pivot bushings.';

  @override
  String get svcDescForkSeals =>
      'Inspect front fork seals for oil weeping & change fork oil.';

  @override
  String get svcDescBrakeRotors =>
      'Measure brake disc thickness & check for warping.';

  @override
  String get svcDescWheelBearings =>
      'Inspect front & rear wheel bearings for play/roughness.';

  @override
  String get svcDescDriveBelt =>
      'Check belt deflection, teeth condition & tension.';

  @override
  String get svcDescFuel => 'Track fuel refills, tank range, and fuel type.';

  @override
  String get svcDescCustom => 'Rider-defined maintenance check.';

  @override
  String get maintCatEngine => 'Engine & Fluids';

  @override
  String get maintCatDrivetrain => 'Drive & Controls';

  @override
  String get maintCatBraking => 'Braking System';

  @override
  String get maintCatChassisElectrical => 'Chassis & Electrical';

  @override
  String serviceOverdueBy(String item, String km) {
    return '$item · overdue by $km km';
  }

  @override
  String serviceDueIn(String item, String km) {
    return '$item · due in $km km';
  }

  @override
  String get noReviewsYet => 'No reviews yet';

  @override
  String get pickLocationMapFirst => 'Pick the location on the map first.';

  @override
  String get takeAPhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String couldNotOpenCamera(Object e) {
    return 'Could not open the camera or gallery: $e';
  }

  @override
  String get couldntLookThatSpot =>
      'Couldn\'t look that spot up — just describe it yourself.';

  @override
  String get photoDidntUploadSaving =>
      'Photo didn\'t upload — saving the place without it.';

  @override
  String couldNotAddPlace(Object e) {
    return 'Could not add place: $e';
  }

  @override
  String get addPhotoOptional => 'Add a photo (optional)';

  @override
  String get shopfrontPictureMakesThis =>
      'A shopfront picture makes this place easy to spot';

  @override
  String get couldntLoadThatPhoto => 'Couldn\'t load that photo';

  @override
  String get replacePhoto => 'Replace photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get addPlace => 'Add Place';

  @override
  String get location => 'Location';

  @override
  String get category => 'Category';

  @override
  String get nameStar => 'Name *';

  @override
  String get eGRahmanMotors => 'e.g. Rahman Motors';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get eGBesideOmuk => 'e.g. Beside Omuk School, Mirpur 10';

  @override
  String get writeItWayYoud =>
      'Write it the way you\'d tell a friend — landmarks, not a formal street address. \"Beside Omuk School\" or \"just after the Mirpur 10 circle\" helps far more here.';

  @override
  String get lookingUp => 'Looking up…';

  @override
  String get usePinsArea => 'Use the pin\'s area';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get hoursOptional => 'Hours (optional)';

  @override
  String get eG9am9pm => 'e.g. 9am - 9pm, or 24/7';

  @override
  String get haventAddedAnyPlaces => 'You haven\'t added any places yet';

  @override
  String verified(Object displayName) {
    return '$displayName · Verified';
  }

  @override
  String get youveAlreadyReviewedThis => 'You\'ve already reviewed this place.';

  @override
  String couldNotSubmitReview(Object e) {
    return 'Could not submit review: $e';
  }

  @override
  String get place => 'Place';

  @override
  String get placeNotFound => 'Place not found';

  @override
  String get addReview => 'Add your review';

  @override
  String get rateThisPlace => 'Rate this place';

  @override
  String get shareExperience => 'Share your experience...';

  @override
  String get submitReview => 'Submit review';

  @override
  String get reviews => 'Reviews';

  @override
  String get noReviewsYetBe => 'No reviews yet — be the first!';

  @override
  String get officialPoint => 'Official point';

  @override
  String get n0NotGoogle => '★ 0 (Not on Google)';

  @override
  String get n00Reviews => '★ 0 (0 reviews)';

  @override
  String get couldntOpenMapsApp => 'Couldn\'t open a maps app for directions';

  @override
  String get couldntOpenDialler => 'Couldn\'t open the dialler';

  @override
  String get call => 'Call';

  @override
  String get youLabel => 'You';

  @override
  String get recordThisRideThrottleiq => 'Record this ride in ThrottleIQ?';

  @override
  String get mapsAppGivesDirections =>
      'Your maps app gives the directions. ThrottleIQ can log the trip in the background at the same time.';

  @override
  String get recordGo => 'Record & go';

  @override
  String get justDirections => 'Just directions';

  @override
  String get dontAskAgain => 'Don\'t ask again';

  @override
  String get noNewPlacesFound => 'No new places found nearby';

  @override
  String couldNotImportNearby(Object e) {
    return 'Could not import nearby places: $e';
  }

  @override
  String get importNearbyPlacesFrom =>
      'Import nearby places from OpenStreetMap';

  @override
  String get allFilter => 'All';

  @override
  String get browseRoutes => 'Browse routes →';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get noPlacesNearbyYet => 'No places nearby yet';

  @override
  String get addGarageFuelPump =>
      'Add a garage, fuel pump, parts shop, or biker cafe to help other riders.';

  @override
  String get addPlaceLower => 'Add place';

  @override
  String couldNotUpdateVisibility(Object e) {
    return 'Could not update visibility: $e';
  }

  @override
  String get deleteRouteQuestion => 'Delete route?';

  @override
  String get thisRemovesSavedRoute =>
      'This removes the saved route. The ride it came from is untouched.';

  @override
  String get deleteRouteTitle => 'Delete route';

  @override
  String get routeNotFound => 'Route not found';

  @override
  String get turns => 'Turns';

  @override
  String get ridden => 'Ridden';

  @override
  String get privateLabel => 'Private';

  @override
  String get anyRiderCanFind => 'Any rider can find and ride this route';

  @override
  String get onlyCanSeeThis => 'Only you can see this route';

  @override
  String get startNavigation => 'Start navigation';

  @override
  String get turnByTurn => 'Turn by turn';

  @override
  String get derivedFromRecordedTrack =>
      'Derived from the recorded track — distances are along the route.';

  @override
  String get sharedByAnotherRider => 'Shared by another rider';

  @override
  String sharedBy(Object value) {
    return 'Shared by $value';
  }

  @override
  String get canRideItBut =>
      'You can ride it, but only its owner can change or delete it.';

  @override
  String get locationPermissionOffSo =>
      'Location permission is off, so turns can\'t be tracked. Enable it in Settings to navigate.';

  @override
  String get locationServicesOffTurn =>
      'Location services are off. Turn them on to navigate.';

  @override
  String get thisRouteHasNo => 'This route has no track to follow.';

  @override
  String offRouteFromLine(Object distanceM) {
    return 'Off route — $distanceM from the line';
  }

  @override
  String get remaining => 'Remaining';

  @override
  String get eta => 'ETA';

  @override
  String get end => 'End';

  @override
  String get routes => 'Routes';

  @override
  String get myRoutes => 'My routes';

  @override
  String get discover => 'Discover';

  @override
  String get noSavedRoutesYet => 'No saved routes yet';

  @override
  String get noPublicRoutesYet => 'No public routes yet';

  @override
  String get finishRideThenTap =>
      'Finish a ride, then tap \"Save as route\" on the share screen.';

  @override
  String get publicRoutesOtherRiders =>
      'Public routes other riders save will show up here.';

  @override
  String routeRiddenSummary(Object distanceKm, Object timesRidden) {
    return '$distanceKm km · ridden $timesRidden×';
  }

  @override
  String get thisRideHasNo => 'This ride has no track to save as a route.';

  @override
  String get routeSaved => 'Route saved';

  @override
  String get loadingTrack => 'Loading track…';

  @override
  String kmPoints(Object distanceKm, Object polylineCount) {
    return '$distanceKm km · $polylineCount points';
  }

  @override
  String get routeName => 'Route name';

  @override
  String get eGDhakaMawa => 'e.g. Dhaka – Mawa morning run';

  @override
  String get giveRouteName => 'Give the route a name';

  @override
  String get roadSurfaceBestTime =>
      'Road surface, best time to ride, where to stop…';

  @override
  String get saveRoute => 'Save route';

  @override
  String get topSpeed => 'Top speed';

  @override
  String get bestScore => 'Best score';

  @override
  String get allRides => 'All rides';

  @override
  String get noRidesYetDot => 'No rides yet.';

  @override
  String showing(Object shownCount, Object sortedCount) {
    return 'Showing $shownCount of $sortedCount';
  }

  @override
  String get distanceLower => 'distance';

  @override
  String get topLower => 'top';

  @override
  String hardBrakesRapidAccel(
      Object hardBrakeCount, Object rapidAccelCount, Object highJerkCount) {
    return '$hardBrakeCount hard brakes · $rapidAccelCount rapid accel · $highJerkCount jerks';
  }

  @override
  String get journey => 'Your Journey';

  @override
  String get goRideStartJourney => 'Go for a ride to start your journey.';

  @override
  String get totalKm => 'total km';

  @override
  String level(Object level, Object rank) {
    return 'Level $level · $rank';
  }

  @override
  String get distanceOverTime => 'Distance over time';

  @override
  String get avgSpeedOverTime => 'Avg speed over time';

  @override
  String badgesEarnedCount(Object earnedCount, Object badgesCount) {
    return '$earnedCount of $badgesCount earned';
  }

  @override
  String get avgSpeedLower => 'avg speed';

  @override
  String get topSpeedLower => 'top speed';

  @override
  String get score => 'score';

  @override
  String get recentRides => 'Recent rides';

  @override
  String get rides => 'Your rides';

  @override
  String shown(Object showing, Object total) {
    return '$showing of $total shown';
  }

  @override
  String badgeFamilyEarned(
      Object family, Object earnedCount, Object badgesCount) {
    return '$family, $earnedCount of $badgesCount earned';
  }

  @override
  String youProgress(Object progress, Object unit) {
    return 'You: $progress $unit';
  }

  @override
  String nextGo(Object def, Object progress, Object unit) {
    return 'Next: $def — $progress $unit to go';
  }

  @override
  String get everyTierEarnedNothing =>
      'Every tier earned. Nothing left to chase here.';

  @override
  String earnedThreshold(Object threshold) {
    return 'Earned. $threshold';
  }

  @override
  String youreAt(
      Object threshold, Object progress, Object threshold2, Object unit) {
    return '$threshold You\'re at $progress of $threshold2 $unit.';
  }

  @override
  String get notEnoughRidesYet => 'Not enough rides yet';

  @override
  String get cropPhoto => 'Crop photo';

  @override
  String get free => 'Free';

  @override
  String get couldNotOpenThat => 'Could not open that photo.';

  @override
  String get couldNotSaveCropped => 'Could not save the cropped photo.';

  @override
  String get done => 'Done';

  @override
  String get rotate => 'Rotate';

  @override
  String get pleaseDescribeProblemBefore =>
      'Please describe the problem before sending.';

  @override
  String get couldNotSendReport =>
      'Could not send the report. Please try again.';

  @override
  String get describeWhatHappenedUid =>
      'Describe what happened. Your UID and app version are included automatically.';

  @override
  String get eGMessagesWouldnt =>
      'e.g. \"Messages wouldn\'t send — I got an error about permissions.\"';

  @override
  String get sending => 'Sending…';

  @override
  String get sendReport => 'Send Report';

  @override
  String get startCaps => 'START';

  @override
  String get finishCaps => 'FINISH';

  @override
  String waypoint(Object selectedPointIndex, Object polylineCount) {
    return 'Waypoint #$selectedPointIndex of $polylineCount';
  }

  @override
  String gpsPointsTapRoute(Object polylineCount) {
    return '$polylineCount GPS points • Tap route to inspect waypoints';
  }

  @override
  String get saveRouteTitle => 'Save Route';

  @override
  String get dragMapMovePin => 'Drag map to move pin';

  @override
  String get noRouteRecorded => 'No route recorded';

  @override
  String get sortRecent => 'Recent';

  @override
  String importedPlaces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count places from OpenStreetMap',
      one: 'Imported 1 place from OpenStreetMap',
    );
    return '$_temp0';
  }

  @override
  String get errOffline =>
      'You\'re offline. Check your internet connection and try again.';

  @override
  String get errTimeout =>
      'That\'s taking too long. Check your connection and try again.';

  @override
  String get errNoPermission => 'You don\'t have permission to view this.';

  @override
  String get errNotFound =>
      'That could not be found — it may have been removed.';

  @override
  String get errTooManyRequests =>
      'Too many requests right now. Please try again in a moment.';

  @override
  String get errNotReady =>
      'This isn\'t ready yet. Please try again in a few minutes.';

  @override
  String get errLoadGeneric =>
      'Something went wrong loading this. Please try again.';

  @override
  String get errUnknown => 'An unknown error occurred';

  @override
  String get authUserNotFound =>
      'No account found with this email. Please sign up first.';

  @override
  String get authWrongPassword => 'Incorrect password. Please try again.';

  @override
  String get authInvalidEmail => 'Invalid email address.';

  @override
  String get authUserDisabled => 'This account has been disabled.';

  @override
  String get authOperationNotAllowed => 'Sign in with email is not enabled.';

  @override
  String get authTooManyRequests =>
      'Too many login attempts. Please try again later.';

  @override
  String get authInvalidCredential => 'Invalid email or password.';

  @override
  String get authEmailInUse => 'An account with this email already exists.';

  @override
  String get authWeakPassword =>
      'Password is too weak. Use at least 6 characters.';

  @override
  String get authNetworkFailed =>
      'Network error. Check your internet connection.';

  @override
  String get authAccountExistsDifferent =>
      'An account exists with this email but different sign-in method.';

  @override
  String get errNetworkFailed =>
      'Network connection failed. Please check your internet.';

  @override
  String get errPermissionDenied =>
      'Permission denied. Please check your account settings.';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errLocationOff =>
      'Location is turned off. Enable GPS in your device settings to use this feature.';

  @override
  String get errLocationPermission =>
      'Location permission is needed for this feature. Grant it in Settings → ThrottleIQ.';

  @override
  String get errLocationGeneric =>
      'Could not get your location. Check that GPS is on and try again.';

  @override
  String authGeneric(String error) {
    return 'Authentication error: $error';
  }

  @override
  String get placeCatFuel => 'Fuel';

  @override
  String get placeCatGarage => 'Garage';

  @override
  String get placeCatParts => 'Parts';

  @override
  String get placeCatAiCamera => 'AI Camera';

  @override
  String get placeCatPolice => 'Police / Cop';

  @override
  String get placeCatRecreation => 'Recreation';

  @override
  String get greetLateNight1 => 'Late night runs, huh?';

  @override
  String get greetLateNight2 => 'The roads are yours at this hour.';

  @override
  String get greetLateNight3 => 'Can\'t sleep? Ride it off.';

  @override
  String greetLateNight4(String name) {
    return 'Empty streets, $name.';
  }

  @override
  String get greetLateNight5 => 'Nobody out there but you.';

  @override
  String get greetEarlyMorning1 => 'Beat the traffic.';

  @override
  String get greetEarlyMorning2 => 'Cold start, clear roads.';

  @override
  String get greetEarlyMorning3 => 'Sunrise miles hit different.';

  @override
  String greetEarlyMorning4(String name) {
    return 'Up early, $name?';
  }

  @override
  String get greetEarlyMorning5 => 'First one out.';

  @override
  String greetMorning1(String name) {
    return 'Morning, $name.';
  }

  @override
  String get greetMorning2 => 'Ready when you are.';

  @override
  String get greetMorning3 => 'Coffee first, then corners.';

  @override
  String get greetMorning4 => 'Fresh tank, fresh day.';

  @override
  String greetMorning5(String name) {
    return 'Where to, $name?';
  }

  @override
  String greetAfternoon1(String name) {
    return 'Afternoon, $name.';
  }

  @override
  String get greetAfternoon2 => 'Good day for it.';

  @override
  String get greetAfternoon3 => 'Sun\'s out. So are the roads.';

  @override
  String greetAfternoon4(String name) {
    return 'Long way home, $name?';
  }

  @override
  String get greetAfternoon5 => 'Perfect time to slip away.';

  @override
  String greetEvening1(String name) {
    return 'Evening, $name.';
  }

  @override
  String get greetEvening2 => 'Golden hour. Go.';

  @override
  String greetEvening3(String name) {
    return 'Sunset run, $name?';
  }

  @override
  String get greetEvening4 => 'Clock out. Gear up.';

  @override
  String get greetEvening5 => 'Best light of the day.';

  @override
  String get greetNight1 => 'Night rider.';

  @override
  String get greetNight2 => 'One more before bed?';

  @override
  String greetNight3(String name) {
    return 'Quiet roads, $name.';
  }

  @override
  String get greetNight4 => 'Cool air, empty lanes.';

  @override
  String greetNight5(String name) {
    return 'Headlights on, $name.';
  }

  @override
  String get greetingNameFallback => 'rider';

  @override
  String get quote0Setup => 'Your ride,';

  @override
  String get quote0Payoff => 'smarter.';

  @override
  String get quote1Setup => 'Two wheels,';

  @override
  String get quote1Payoff => 'one heartbeat.';

  @override
  String get quote2Setup => 'Every ride,';

  @override
  String get quote2Payoff => 'a story worth logging.';

  @override
  String get quote3Setup => 'Trust the throttle,';

  @override
  String get quote3Payoff => 'respect the road.';

  @override
  String get quote4Setup => 'The road ahead';

  @override
  String get quote4Payoff => 'is the only plan you need.';

  @override
  String get quote5Setup => 'Ride the wind,';

  @override
  String get quote5Payoff => 'own the road.';

  @override
  String get quote6Setup => 'Smooth is fast.';

  @override
  String get quote6Payoff => 'Fast is smooth.';

  @override
  String get quote7Setup => 'Some roads';

  @override
  String get quote7Payoff => 'you don\'t forget.';

  @override
  String get quote8Setup => 'Chase the horizon,';

  @override
  String get quote8Payoff => 'not the redline.';

  @override
  String get quote9Setup => 'Miles make';

  @override
  String get quote9Payoff => 'the machine yours.';

  @override
  String get quote10Setup => 'Every gear change';

  @override
  String get quote10Payoff => 'is a decision.';

  @override
  String get quote11Setup => 'Ride far.';

  @override
  String get quote11Payoff => 'Ride smart.';

  @override
  String get quote12Setup => 'The best rides';

  @override
  String get quote12Payoff => 'start with no plan.';

  @override
  String get quote13Setup => 'Two wheels,';

  @override
  String get quote13Payoff => 'infinite roads.';

  @override
  String get quote14Setup => 'Momentum is';

  @override
  String get quote14Payoff => 'a kind of freedom.';

  @override
  String get quote15Setup => 'Read the road';

  @override
  String get quote15Payoff => 'before it reads you.';

  @override
  String get noRatingsYet => 'No ratings yet';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get statusOk => 'OK';

  @override
  String get crashSuspectedBadge => 'Suspected crash';

  @override
  String scoreValue(int score) {
    return 'Score $score';
  }

  @override
  String get activePill => 'Active';

  @override
  String get captionLabel => 'Caption';

  @override
  String get commentsLabel => 'Comments';

  @override
  String get ridersLabel => 'Riders';

  @override
  String get rankNewRider => 'New Rider';

  @override
  String get rankWeekendRider => 'Weekend Rider';

  @override
  String get rankSteadyCruiser => 'Steady Cruiser';

  @override
  String get rankRoadRegular => 'Road Regular';

  @override
  String get rankSeasonedRider => 'Seasoned Rider';

  @override
  String get rankRoadMaster => 'Road Master';

  @override
  String get tiersLabel => 'Tiers';

  @override
  String get rankVeteran => 'Veteran';

  @override
  String get badgeFamFirstName => 'First ride';

  @override
  String get badgeFamFirstAbout =>
      'Where every rider starts — your first recorded ride.';

  @override
  String get badgeFamFirstReq => 'Record your first ride.';

  @override
  String get badgeRungFirstRide => 'First ride';

  @override
  String get badgeFamRidesName => 'Rides';

  @override
  String get badgeFamRidesAbout =>
      'How many rides you have recorded, all time.';

  @override
  String badgeFamRidesReq(String n) {
    return 'Record $n rides.';
  }

  @override
  String get badgeRungRides10 => '10 rides';

  @override
  String get badgeRungRides25 => '25 rides';

  @override
  String get badgeRungRides50 => '50 rides';

  @override
  String get badgeRungRides100 => '100 rides';

  @override
  String get badgeRungRides250 => '250 rides';

  @override
  String get badgeFamDistanceName => 'Distance';

  @override
  String get badgeFamDistanceAbout =>
      'Total distance covered across every ride you have recorded.';

  @override
  String badgeFamDistanceReq(String n) {
    return 'Ride $n km in total.';
  }

  @override
  String get badgeRungKm100 => '100 km';

  @override
  String get badgeRungKm500 => '500 km';

  @override
  String get badgeRungKm1000 => '1,000 km';

  @override
  String get badgeRungKm2500 => '2,500 km';

  @override
  String get badgeRungKm5000 => '5,000 km';

  @override
  String get badgeFamLongRideName => 'Longest ride';

  @override
  String get badgeFamLongRideAbout =>
      'The distance of your single longest recorded ride.';

  @override
  String badgeFamLongRideReq(String n) {
    return 'Cover $n km in one ride.';
  }

  @override
  String get badgeRungLongRide50 => 'Day tripper';

  @override
  String get badgeRungLongRide100 => 'Century';

  @override
  String get badgeRungLongRide200 => 'Long hauler';

  @override
  String get badgeRungLongRide400 => 'Tourer';

  @override
  String get badgeRungLongRide800 => 'Iron rider';

  @override
  String get badgeFamSaddleTimeName => 'Saddle time';

  @override
  String get badgeFamSaddleTimeAbout =>
      'The duration of your single longest recorded ride.';

  @override
  String badgeFamSaddleTimeReq(String n) {
    return 'Ride for $n hours without ending the recording.';
  }

  @override
  String get badgeRungSaddle1h => 'One hour';

  @override
  String get badgeRungSaddle2h => 'Two hours';

  @override
  String get badgeRungSaddle4h => 'Four hours';

  @override
  String get badgeRungSaddle8h => 'Eight hours';

  @override
  String get badgeFamSpeedName => 'Top speed';

  @override
  String get badgeFamSpeedAbout =>
      'The highest speed recorded on any of your rides.';

  @override
  String badgeFamSpeedReq(String n) {
    return 'Record a top speed of $n km/h.';
  }

  @override
  String get badgeRungTonUp => 'Ton-up';

  @override
  String get badgeRungSpeed140 => 'Quick';

  @override
  String get badgeRungSpeedDemon => 'Speed demon';

  @override
  String get badgeFamNightName => 'Night rider';

  @override
  String get badgeFamNightAbout =>
      'Rides that set off after 9 pm or before 4 am.';

  @override
  String badgeFamNightReq(String n) {
    return 'Start $n rides between 9 pm and 4 am.';
  }

  @override
  String get badgeRungNight1 => 'After dark';

  @override
  String get badgeRungNight5 => 'Night owl';

  @override
  String get badgeRungNight25 => 'Moonlighter';

  @override
  String get badgeRungNight50 => 'Nocturnal';

  @override
  String get badgeFamEarlyName => 'Early bird';

  @override
  String get badgeFamEarlyAbout => 'Rides that set off between 4 am and 7 am.';

  @override
  String badgeFamEarlyReq(String n) {
    return 'Start $n rides between 4 am and 7 am.';
  }

  @override
  String get badgeRungEarly1 => 'Sunrise run';

  @override
  String get badgeRungEarly5 => 'Early bird';

  @override
  String get badgeRungEarly25 => 'Dawn patrol';

  @override
  String get badgeFamStreakName => 'Streak';

  @override
  String get badgeFamStreakAbout =>
      'Your longest run of consecutive days with a recorded ride.';

  @override
  String badgeFamStreakReq(String n) {
    return 'Ride on $n days in a row.';
  }

  @override
  String get badgeRungStreak3 => '3-day streak';

  @override
  String get badgeRungStreak7 => '7-day streak';

  @override
  String get badgeRungStreak14 => '14-day streak';

  @override
  String get badgeRungStreak30 => '30-day streak';

  @override
  String get badgeFamSmoothName => 'Smoothness';

  @override
  String get badgeFamSmoothAbout =>
      'Your average riding score — fewer hard brakes, rapid accelerations and jerky inputs score higher.';

  @override
  String badgeFamSmoothReq(String n) {
    return 'Average $n points across at least 5 rides.';
  }

  @override
  String get badgeRungSmooth80 => 'Steady hands';

  @override
  String get badgeRungSmoothOperator => 'Smooth operator';

  @override
  String get badgeRungSmooth95 => 'Silk';

  @override
  String get badgeRungSmooth98 => 'Effortless';

  @override
  String get badgeUnitRides => 'rides';

  @override
  String get badgeUnitKm => 'km';

  @override
  String get badgeUnitHours => 'h';

  @override
  String get badgeUnitKmh => 'km/h';

  @override
  String get badgeUnitDays => 'days';

  @override
  String get badgeUnitPts => 'pts';

  @override
  String get badgeTierBronze => 'Bronze';

  @override
  String get badgeTierSilver => 'Silver';

  @override
  String get badgeTierGold => 'Gold';

  @override
  String get badgeTierPlatinum => 'Platinum';

  @override
  String get badgeTierDiamond => 'Diamond';

  @override
  String get turnStart => 'Start';

  @override
  String get turnSlightLeft => 'Slight left';

  @override
  String get turnLeft => 'Turn left';

  @override
  String get turnSharpLeft => 'Sharp left';

  @override
  String get turnSlightRight => 'Slight right';

  @override
  String get turnRight => 'Turn right';

  @override
  String get turnSharpRight => 'Sharp right';

  @override
  String get turnUTurn => 'Make a U-turn';

  @override
  String get turnStraight => 'Continue straight';

  @override
  String get turnArrive => 'You have arrived';

  @override
  String get compassNorth => 'north';

  @override
  String get compassNorthEast => 'north-east';

  @override
  String get compassEast => 'east';

  @override
  String get compassSouthEast => 'south-east';

  @override
  String get compassSouth => 'south';

  @override
  String get compassSouthWest => 'south-west';

  @override
  String get compassWest => 'west';

  @override
  String get compassNorthWest => 'north-west';

  @override
  String turnHead(String direction) {
    return 'Head $direction';
  }

  @override
  String get notifChannelCrash => 'Crash alerts';

  @override
  String get notifChannelCrashDesc =>
      'Shown when ThrottleIQ thinks you may have crashed. Do not disable.';

  @override
  String get notifChannelRides => 'Ride confirmations';

  @override
  String get notifChannelRidesDesc =>
      'Asks which bike an automatically-detected ride was on.';

  @override
  String get notifChannelDigest => 'Weekly digest';

  @override
  String get notifChannelDigestDesc => 'Your weekly riding summary.';

  @override
  String get notifCrashTitle => 'Crash detected';

  @override
  String notifCrashBody(int seconds) {
    return 'Contacting your emergency contacts in ${seconds}s unless you tap \"I\'m OK\".';
  }

  @override
  String get notifImOk => 'I\'m OK';

  @override
  String notifRideDetectedTitle(String km) {
    return 'Ride detected — $km km';
  }

  @override
  String notifRideDetectedBody(String bike) {
    return 'We logged this to $bike. Tap to confirm or change.';
  }

  @override
  String get notifConfirm => 'Confirm';

  @override
  String get notifDigestTitle => 'Today on the road';

  @override
  String get notifDigestTap => 'Tap to see your day.';

  @override
  String notifDigestSummary(int rides, String km) {
    String _temp0 = intl.Intl.pluralLogic(
      rides,
      locale: localeName,
      other: '$rides rides',
      one: '1 ride',
    );
    return '$_temp0, $km km';
  }

  @override
  String notifDigestUnconfirmed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need a bike confirmed',
      one: '1 needs a bike confirmed',
    );
    return ' · $_temp0';
  }

  @override
  String get shareUsageStats => 'Share anonymous usage statistics';

  @override
  String get shareUsageStatsDesc =>
      'Which screens are used and a few key steps, like starting a ride. Never your location, rides, messages or name — and no advertising.';

  @override
  String get safeQrPrintAction => 'Print sticker';

  @override
  String get safeQrStickerTitle => 'EMERGENCY MEDICAL INFO';

  @override
  String get safeQrStickerCaption =>
      'Scan with any phone camera. Works offline.';

  @override
  String get safeQrPrintFailed => 'Couldn\'t open the print dialog.';

  @override
  String get feedSortHot => 'Hot';
}
