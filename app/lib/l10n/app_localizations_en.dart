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
}
