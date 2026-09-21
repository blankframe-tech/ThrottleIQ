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
}
