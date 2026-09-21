// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get riderFallbackName => 'রাইডার';

  @override
  String get appearanceSection => 'অ্যাপের চেহারা';

  @override
  String get vibeFieldLabel => 'ভাইব';

  @override
  String get vibeBoxyLabel => 'বক্সি';

  @override
  String get vibeBoxyDescription => 'ধারালো কোণ';

  @override
  String get vibeCurvyLabel => 'কার্ভি';

  @override
  String get vibeCurvyDescription => 'গোল কোণ';

  @override
  String get brightnessFieldLabel => 'উজ্জ্বলতা';

  @override
  String get brightnessDarkLabel => 'গাঢ়';

  @override
  String get brightnessDarkDescription => 'গাঢ় বেস';

  @override
  String get brightnessLightLabel => 'হালকা';

  @override
  String get brightnessLightDescription => 'হালকা বেস';

  @override
  String get brightnessSystemLabel => 'সিস্টেম';

  @override
  String get brightnessSystemDescription => 'ফোনের সেটিং অনুসরণ করুন';

  @override
  String get colorFieldLabel => 'রং';

  @override
  String get themeCarbonLabel => 'কার্বন মোনো';

  @override
  String get themeCarbonDescription => 'লাইম আর ম্যাজেন্টা';

  @override
  String get themeEditorialLabel => 'এডিটোরিয়াল';

  @override
  String get themeEditorialDescription => 'নীল আর কমলা, কাগজের উষ্ণতা';

  @override
  String get themeNocturneLabel => 'নকটার্ন';

  @override
  String get themeNocturneDescription => 'গাঢ় নীল আর বেগুনি আভা';

  @override
  String get themeTrailSocialLabel => 'ট্রেইল সোশ্যাল';

  @override
  String get themeTrailSocialDescription => 'ঝলমলে কমলা';

  @override
  String get themeCalmingLabel => 'কামিং';

  @override
  String get themeCalmingDescription => 'উষ্ণ সবুজ আর বাদামি';

  @override
  String get themeRetroLabel => 'রেট্রো';

  @override
  String get themeRetroDescription => '70-দশকের পোস্টার, সরিষা ও মরিচা রং';

  @override
  String get themeAnalystBlueLabel => 'অ্যানালিস্ট ব্লু';

  @override
  String get themeAnalystBlueDescription => 'নেভি কনসোল, সায়ান মিটার';

  @override
  String get languageSection => 'ভাষা';

  @override
  String get languageSystemLabel => 'ফোনের ভাষা';

  @override
  String get languageSystemDescription => 'ফোনে যা সেট করা আছে';

  @override
  String get languageEnglishLabel => 'English';

  @override
  String get languageEnglishDescription => 'সবসময় ইংরেজি';

  @override
  String get languageBanglaLabel => 'বাংলা';

  @override
  String get languageBanglaDescription => 'সবসময় বাংলা';

  @override
  String get emergencyContactsSection => 'জরুরি যোগাযোগ';

  @override
  String get emergencyContactsDescription =>
      'দুর্ঘটনা ধরা পড়লে ও আপনি 60 সেকেন্ডের মধ্যে সাড়া না দিলে তা লগ করা হবে — স্বয়ংক্রিয় SMS/ইমেইল সতর্কতা এখনো চালু হয়নি।';

  @override
  String get emergencyContactsNotAlertedBanner =>
      'ThrottleIQ এখনো এই যোগাযোগগুলোকে স্বয়ংক্রিয়ভাবে সতর্ক করে না।';

  @override
  String get emergencyContactsAckTitle => 'যোগাযোগগুলোকে এখনো সতর্ক করা হয় না';

  @override
  String get emergencyContactsAckBody =>
      'ThrottleIQ এই যোগাযোগটি সংরক্ষণ করেছে, কিন্তু দুর্ঘটনার পরে এখনো তাঁকে SMS বা ইমেইল পাঠাতে পারে না। যতদিন না পারে, রাইডে বের হওয়ার আগে কাউকে আপনার রুট জানিয়ে রাখুন।';

  @override
  String get emergencyContactsAckAction => 'বুঝেছি';

  @override
  String get emergencyContactsEmpty =>
      'এখনো কাউকে যোগ করা হয়নি — বিশ্বাস করেন এমন কাউকে রাখুন।';

  @override
  String emergencyContactsLoadError(String error) {
    return 'কন্টাক্ট লোড করা গেল না: $error';
  }

  @override
  String get addAction => 'যোগ করুন';

  @override
  String get cancelAction => 'বাতিল';

  @override
  String get addEmergencyContactTitle => 'জরুরি যোগাযোগ যোগ করুন';

  @override
  String get contactNameField => 'নাম';

  @override
  String get contactPhoneField => 'ফোন নম্বর';

  @override
  String get contactEmailFieldOptional => 'ইমেইল (না দিলেও চলবে)';

  @override
  String get signOutAction => 'সাইন আউট';

  @override
  String get navSocialLabel => 'সোশ্যাল';

  @override
  String get navRidesLabel => 'রাইড';

  @override
  String get navRecordLabel => 'রেকর্ড';

  @override
  String get navPlacesLabel => 'স্থান';

  @override
  String get navProfileLabel => 'প্রোফাইল';

  @override
  String get bikePickerSheetTitle => 'আজ চালাচ্ছেন';

  @override
  String rideCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি রাইড',
      one: '$countটি রাইড',
    );
    return '$_temp0';
  }

  @override
  String get changeAction => 'পাল্টান';

  @override
  String get ridesStatLabel => 'রাইড';

  @override
  String get kilometresStatLabel => 'কিলোমিটার';

  @override
  String get dayStreakStatLabel => 'দিনের ধারা';

  @override
  String get rideNotFoundMessage => 'রাইড খুঁজে পাওয়া যায়নি';

  @override
  String get niceRideGreeting => 'চমৎকার রাইড হলো!';

  @override
  String niceRideGreetingNamed(String name) {
    return 'চমৎকার রাইড হলো, $name!';
  }

  @override
  String get distanceStatLabel => 'কিমি';

  @override
  String get durationStatLabel => 'সময়';

  @override
  String get avgSpeedStatLabel => 'গড়';

  @override
  String get maxSpeedStatLabel => 'সর্বোচ্চ';

  @override
  String get movingStatLabel => 'চলমান';

  @override
  String get jamStatLabel => 'জ্যামে';

  @override
  String get scoreSmoothLabel => 'মসৃণ';

  @override
  String get scoreSteadyLabel => 'স্থির';

  @override
  String get scoreAggressiveLabel => 'বেপরোয়া';

  @override
  String get speedBandIdleLabel => 'নিষ্ক্রিয়';

  @override
  String get speedBandNormalLabel => 'স্বাভাবিক';

  @override
  String get speedBandBriskLabel => 'দ্রুত';

  @override
  String get speedBandHardLabel => 'অতি দ্রুত';

  @override
  String get speedOutlierTitle => 'এখানে স্বাভাবিকের চেয়ে দ্রুত';

  @override
  String speedOutlierBody(int riderKmh, int baselineKmh) {
    return 'এই রাইডের একটি অংশে আপনি $riderKmh কিমি/ঘ গতিতে ছিলেন — এখানে রাইডাররা সাধারণত প্রায় $baselineKmh কিমি/ঘ গতিতে চলে।';
  }

  @override
  String get ridingScoreLabel => 'রাইডিং স্কোর';

  @override
  String get outOf100Label => '100 এর মধ্যে';

  @override
  String get hardBrakesStatLabel => 'হার্ড ব্রেক';

  @override
  String get rapidAccelStatLabel => 'হঠাৎ গতি';

  @override
  String get highJerkStatLabel => 'তীব্র ঝাঁকুনি';

  @override
  String get routeSectionLabel => 'রুট';

  @override
  String get saveAndDoneAction => 'সেভ করে শেষ';

  @override
  String get shareAction => 'শেয়ার করুন';

  @override
  String get exportJsonAction => 'JSON এক্সপোর্ট করুন';

  @override
  String get exportGpxAction => 'GPX এক্সপোর্ট করুন';

  @override
  String get exportCsvAction => 'CSV এক্সপোর্ট করুন';

  @override
  String get exportFailedMessage => 'এক্সপোর্ট ব্যর্থ হয়েছে';

  @override
  String get telemetrySectionLabel => 'টেলিমেট্রি';

  @override
  String get ridingPaceLabel => 'গড় চলন্ত গতি';

  @override
  String get movingStoppedLabel => 'চলমান / থেমে থাকা';

  @override
  String get routeGpsDetailsLabel => 'রুট GPS বিবরণ';

  @override
  String trackPointsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি ট্র্যাক পয়েন্ট',
      one: '1টি ট্র্যাক পয়েন্ট',
    );
    return '$_temp0';
  }

  @override
  String get startPointLabel => 'শুরু';

  @override
  String get finishPointLabel => 'শেষ';

  @override
  String get exploreFullRouteAction => 'সম্পূর্ণ রুট ম্যাপে দেখুন';

  @override
  String get saveAsRouteAction => 'রুট হিসেবে সেভ করুন';

  @override
  String get mapExpandHintLabel => 'বড় করতে ম্যাপে ট্যাপ করুন';

  @override
  String get elevationGainLabel => 'উচ্চতা বৃদ্ধি';

  @override
  String get elevationLossLabel => 'উচ্চতা হ্রাস';

  @override
  String get elevationProfileLabel => 'উচ্চতার প্রোফাইল';

  @override
  String get speedProfileLabel => 'গতির প্রোফাইল';

  @override
  String get rideExportShareSubject => 'ThrottleIQ রাইড এক্সপোর্ট';

  @override
  String get autoTrackingTileTitle => 'স্বয়ংক্রিয়ভাবে রাইড শনাক্ত করুন';

  @override
  String get autoTrackingTileSubtitle =>
      'আপনি স্টার্ট না চাপলেও রাইড লগ করে রাখে। রাইড না করলে দিনে প্রায় 3–5% ব্যাটারি খরচ হয়।';

  @override
  String get autoTrackingLocationServicesOffMessage =>
      'রাইড শনাক্ত করতে ThrottleIQ-কে লোকেশন সার্ভিস চালু করুন।';

  @override
  String get autoTrackingPermissionDeniedMessage =>
      'রাইড শনাক্ত করতে লোকেশন অনুমতি প্রয়োজন।';

  @override
  String get autoTrackingAlwaysPermissionRequiredMessage =>
      'অ্যাপ বন্ধ থাকা অবস্থায় রাইড শনাক্ত করতে ThrottleIQ-এর \"সবসময়\" লোকেশন অ্যাক্সেস প্রয়োজন। এটি আপনি সেটিংস থেকে পরিবর্তন করতে পারবেন।';

  @override
  String get autoTrackingStartFailedMessage =>
      'এই ডিভাইসে ব্যাকগ্রাউন্ড ট্র্যাকিং চালু করা যায়নি।';

  @override
  String get bikeConfirmationTitle => 'এটি কোন বাইকে হয়েছে?';

  @override
  String get bikeConfirmationBody =>
      'আমরা এই রাইডটি স্বয়ংক্রিয়ভাবে শনাক্ত করে আপনার সক্রিয় বাইকে যুক্ত করেছি। সার্ভিস রিমাইন্ডার সঠিক রাখতে নিশ্চিত করুন।';

  @override
  String get bikeConfirmationUpdatedMessage => 'রাইড আপডেট হয়েছে।';

  @override
  String loggedToBikeLabel(String bikeName) {
    return '$bikeName-এ লগ করা হয়েছে';
  }

  @override
  String get changeBikeSheetTitle => 'বাইক পরিবর্তন করুন';

  @override
  String get rideModeSoloLabel => 'একা';

  @override
  String get rideModeGroupLabel => 'গ্রুপ';

  @override
  String get rideModeInviteFriendsAction => 'বন্ধুদের আমন্ত্রণ জানান';

  @override
  String get rideModeJoinByCodeAction => 'কোড দিয়ে যোগ দিন';

  @override
  String get joinRideByCodeTitle => 'রাইডে যোগ দিন';

  @override
  String get joinRideByCodeSubtitle =>
      'রাইড তৈরিকারী আপনাকে যে 6-অক্ষরের কোড দিয়েছেন তা লিখুন।';

  @override
  String get joinRideCodeHint => 'ABC123';

  @override
  String get joinRideAction => 'যোগ দিন';

  @override
  String get joinRideCodeInvalidFormat => 'এটি সঠিক কোড বলে মনে হচ্ছে না।';

  @override
  String get joinRideGenericError =>
      'এই রাইডে যোগ দেওয়া যায়নি। কোডটি পরীক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get safeQrTitle => 'SafeQR';

  @override
  String get safeQrSettingsSubtitle =>
      'জরুরি সেবাদানকারীদের জন্য স্ক্যান করার মতো মেডিকেল তথ্য কার্ড';

  @override
  String get safeQrIntro =>
      'যে কেউ ফোনের ক্যামেরা দিয়ে এটি স্ক্যান করতে পারবে — তাদের কোনো অ্যাপ বা অ্যাকাউন্টের দরকার নেই। জরুরি সেবাদানকারী বা ট্রাফিক পুলিশ জানলে ভালো হয় এমন তথ্য পূরণ করুন।';

  @override
  String get safeQrEmptyStateHint =>
      'আপনার কার্ড তৈরি করতে নিচে রক্তের গ্রুপ যোগ করুন';

  @override
  String get safeQrMedicalInfoSection => 'মেডিকেল তথ্য';

  @override
  String get safeQrBloodGroupField => 'রক্তের গ্রুপ';

  @override
  String get safeQrBloodGroupHint => 'যেমন O+';

  @override
  String get safeQrAllergiesField => 'অ্যালার্জি';

  @override
  String get safeQrConditionsField => 'শারীরিক অবস্থা';

  @override
  String get safeQrMedicationsField => 'বর্তমান ওষুধ';

  @override
  String safeQrContactIncludedNote(String name) {
    return '$name (আপনার প্রথম জরুরি যোগাযোগ) স্বয়ংক্রিয়ভাবে যুক্ত করা হয়েছে।';
  }

  @override
  String get safeQrNoContactNote =>
      'এই কার্ডে স্বয়ংক্রিয়ভাবে যুক্ত করতে উপরে একটি জরুরি যোগাযোগ যোগ করুন।';

  @override
  String get safeQrSaveAction => 'সংরক্ষণ করুন';

  @override
  String get safeQrSavedMessage => 'SafeQR তথ্য সংরক্ষিত হয়েছে।';

  @override
  String get safeQrLocalOnlyDisclaimer =>
      'শুধুমাত্র এই ডিভাইসে সংরক্ষিত — এটি ব্যাকআপ বা সিঙ্ক করা হয় না।';

  @override
  String get safeQrShareImageAction => 'QR ছবি সংরক্ষণ বা শেয়ার করুন';

  @override
  String get safeQrShareImageFailed => 'QR ছবি তৈরি করা গেল না।';

  @override
  String get weatherUnavailableTooltip =>
      'এই রাইডের আবহাওয়ার তথ্য পাওয়া যায়নি';

  @override
  String get weatherUnavailableLabel => 'আবহাওয়া তথ্য নেই';

  @override
  String get overspeedSettingTitle => 'সর্বোচ্চ গতির সতর্কতা সীমা';

  @override
  String get overspeedSettingSubtitle =>
      'এই গতি অতিক্রম করলে হ্যাপটিক ও ভিজ্যুয়াল সতর্কতা';

  @override
  String get iosAutoTrackingAdvisory =>
      'iOS-এ নিরবচ্ছিন্ন রাইড শনাক্তকরণের জন্য অ্যাপ সুইচার থেকে সোয়াইপ করে বন্ধ না করে থ্রটলআইকিউ ব্যাকগ্রাউন্ডে চালু রাখুন।';

  @override
  String get recentDetectionsTitle => 'স্বয়ংক্রিয় শনাক্তকরণ ইতিহাস';

  @override
  String get recentDetectionsSubtitle =>
      'স্বয়ংক্রিয়ভাবে রেকর্ডকৃত বা বাতিলকৃত সাম্প্রতিক ট্রিপ দেখুন';

  @override
  String get recentDetectionsEmpty =>
      'এখনো কোনো স্বয়ংক্রিয় শনাক্তকরণ লগ নেই।';

  @override
  String get rejectionTooShort => 'ট্রিপের দূরত্ব খুব কম ছিল';

  @override
  String get rejectionTooSlow => 'গতি খুব কম ছিল বিধায় রাইড গণ্য হয়নি';

  @override
  String get rejectionTooFewFixes => 'পর্যাপ্ত জিপিএস তথ্য পাওয়া যায়নি';

  @override
  String get rejectionNoMovement => 'যানবাহনের চলাচল শনাক্ত হয়নি';

  @override
  String get rideAlertHardBraking => 'ব্রেক আস্তে চাপুন';

  @override
  String get rideAlertRapidAccel => 'থ্রটল আস্তে ঘোরান';

  @override
  String get rideAlertOverspeed => 'গতি খেয়াল রাখুন';

  @override
  String get rideAlertFatigue => 'বিরতি নেওয়ার সময়';

  @override
  String get liveShareAgainAction => 'লিংক আবার শেয়ার করুন';

  @override
  String get liveShareStopAction => 'শেয়ার করা বন্ধ করুন';

  @override
  String get liveShareStopDescription =>
      'লিংকটি আর কাজ করবে না। আপনার রাইড রেকর্ড হতে থাকবে।';

  @override
  String get email => 'ইমেইল';

  @override
  String get emailRequired => 'ইমেইল দিতে হবে';

  @override
  String get invalidEmail => 'ইমেইলটি সঠিক নয়';

  @override
  String get password => 'পাসওয়ার্ড';

  @override
  String get showPassword => 'পাসওয়ার্ড দেখান';

  @override
  String get passwordTooShort => 'পাসওয়ার্ড খুব ছোট';

  @override
  String get signIn => 'সাইন ইন';

  @override
  String get orDivider => 'অথবা';

  @override
  String get continueWithGoogle => 'গুগল দিয়ে চালিয়ে যান';

  @override
  String get noAccountPrompt => 'অ্যাকাউন্ট নেই? ';

  @override
  String get signUp => 'সাইন আপ';

  @override
  String get welcomeBack => 'আবার স্বাগতম';

  @override
  String get signInSubtitle => 'রাইড ট্র্যাক করতে সাইন ইন করুন';

  @override
  String get yourGarage => 'আপনার গ্যারেজ';

  @override
  String get everyBikeOwnTracked => 'আপনার সব বাইক, এক জায়গায় ট্র্যাক করা।';

  @override
  String get addUnlimitedBikesBrand =>
      'আনলিমিটেড বাইক যোগ করুন — ব্র্যান্ড, মডেল, বছর, সিসি';

  @override
  String get bikesPaintColorTints =>
      'আপনার বাইকের রঙে পুরো অ্যাপের থিম বদলে যায়';

  @override
  String get tapAnyBikeView => 'বাইকে ট্যাপ করে পুরো ইতিহাস ও বিস্তারিত দেখুন';

  @override
  String get switchActiveBikeBefore =>
      'প্রতিটি রাইডের আগে সক্রিয় বাইক বদলে নিন';

  @override
  String get activeMotorcycle => 'সক্রিয় মোটরসাইকেল';

  @override
  String get tintsEntireAppTheme =>
      'পুরো অ্যাপের থিমে রং ছড়িয়ে দেয় এবং আপনার ট্রিপ লগের সাথে যুক্ত হয়।';

  @override
  String get serviceCountdown => 'সার্ভিস কাউন্টডাউন';

  @override
  String get realTimeMaintenanceTracker =>
      'আসলে চালানো কিমি ধরে রিয়েল-টাইম মেইনটেন্যান্স ট্র্যাকার।';

  @override
  String get addSwitch => 'যোগ ও পরিবর্তন';

  @override
  String get manageMultipleBikesSwap =>
      'একাধিক বাইক পরিচালনা করুন এবং যখন খুশি সক্রিয় বাইক বদলান।';

  @override
  String get startRide => 'রাইড শুরু করুন';

  @override
  String get holdButtonThrottleiqDoes =>
      'বোতামটি ধরে রাখুন। বাকিটা ThrottleIQ করবে।';

  @override
  String get holdStartRecordTab => 'শুরু করতে রেকর্ড ট্যাবে ধরে রাখুন';

  @override
  String get gpsSensorFusionCaptures =>
      'GPS ও সেন্সর মিলিয়ে প্রতিটি মুহূর্ত ধরা হয়';

  @override
  String get continuesRecordingBackground =>
      'ব্যাকগ্রাউন্ডেও রেকর্ডিং চলতে থাকে';

  @override
  String get pausedRideSurvivesApp =>
      'বিরতি দেওয়া রাইড অ্যাপ বন্ধ করলেও থেকে যায়';

  @override
  String get shareLiveLocationWith =>
      'পরিবারের সাথে রিয়েল-টাইমে আপনার লাইভ লোকেশন শেয়ার করুন';

  @override
  String get cockpitTelemetry => 'ককপিট টেলিমেট্রি';

  @override
  String get liveGpsSpeedDistance =>
      'চলার সাথে সাথে লাইভ GPS গতি, দূরত্ব ও রাইডের তথ্য।';

  @override
  String get hold1sRecord => 'রেকর্ড করতে 1 সেকেন্ড ধরে রাখুন';

  @override
  String get hold1sStartStop =>
      'শুরু বা শেষ করতে 1 সেকেন্ড ধরে রাখুন; ভুলে ছোঁয়া থেকে রক্ষা করে।';

  @override
  String get liveShare => 'লাইভ শেয়ার';

  @override
  String get sendRevocableLinkSo =>
      'বাতিলযোগ্য একটি লিংক পাঠান, যাতে পরিবার আপনার রাইড অনুসরণ করতে পারে।';

  @override
  String get autoTracking => 'অটো ট্র্যাকিং';

  @override
  String get ridesThatDetectRecord => 'নিজে থেকেই রাইড শনাক্ত ও রেকর্ড হয়।';

  @override
  String get enableOnceSettingsAuto =>
      'সেটিংস → অটো-ট্র্যাকিং থেকে একবার চালু করুন';

  @override
  String get activityRecognitionStartsRecording =>
      'আপনি চালানো শুরু করলে অ্যাক্টিভিটি শনাক্তকরণ রেকর্ডিং শুরু করে';

  @override
  String get shortWalksSubwayTrips =>
      'ছোট হাঁটা ও সাবওয়ে ট্রিপ বাদ দেওয়া হয়';

  @override
  String get eachAutoDetectedRide =>
      'প্রতিটি অটো-শনাক্ত রাইড রিভিউয়ের জন্য প্রস্তুত থাকে';

  @override
  String get smartDetection => 'স্মার্ট শনাক্তকরণ';

  @override
  String get detectsMotorcycleMovementVia =>
      'IMU সেন্সর ও গতি দেখে মোটরসাইকেলের চলাচল শনাক্ত করে।';

  @override
  String get nonRideFilter => 'নন-রাইড ফিল্টার';

  @override
  String get ignoresWalkingBusRides =>
      'হাঁটা, বাস যাত্রা ও ফোন সামান্য নড়াচড়া উপেক্ষা করে।';

  @override
  String get zeroInteraction => 'শূন্য ঝামেলা';

  @override
  String get runsSilentlyBackgroundReview =>
      'ব্যাকগ্রাউন্ডে নীরবে চলে; শেষ হলে রাইড রিভিউ করুন।';

  @override
  String get maintenance => 'মেইনটেন্যান্স';

  @override
  String get neverForgetAnotherOil => 'তেল বদলানোর কথা আর কখনো ভুলবেন না।';

  @override
  String get alertsWhenYoureDue =>
      'তেল, ফিল্টার, চেইন লুব… এর সময় হলে অ্যালার্ট';

  @override
  String get logServiceResetCountdown =>
      'কাউন্টডাউন রিসেট করতে সার্ভিস লগ করুন';

  @override
  String get addCustomIntervalsAny =>
      'যেকোনো যন্ত্রাংশের জন্য নিজের মতো ইন্টারভাল যোগ করুন';

  @override
  String get n13ServiceItems => '13+ সার্ভিস আইটেম';

  @override
  String get trackEngineOilChain =>
      'ইঞ্জিন অয়েল, চেইন লুব, ব্রেক ফ্লুইড, কুল্যান্টসহ আরও অনেক কিছু ট্র্যাক করুন।';

  @override
  String get dueBadges => 'ডিউ ব্যাজ';

  @override
  String get colorCodedProgressBars =>
      'ইন্টারভাল শেষ হওয়ার আগেই রঙিন প্রগ্রেস বার সতর্ক করে।';

  @override
  String get logReset => 'লগ ও রিসেট';

  @override
  String get recordMaintenanceNotesReset =>
      'মেইনটেন্যান্সের নোট রাখুন এবং ইন্টারভাল ওডোমিটার রিসেট করুন।';

  @override
  String get riderPlaces => 'রাইডার প্লেসেস';

  @override
  String get everyGaragePumpViewpoint =>
      'আপনার কাছের প্রতিটি গ্যারেজ, পাম্প ও ভিউপয়েন্ট।';

  @override
  String get fuelStationsRepairShops =>
      'জ্বালানি স্টেশন, মেরামতের দোকান, যন্ত্রাংশ ও ক্যাফে';

  @override
  String get tapDirectionsOpensMaps =>
      'ডিরেকশনসে ট্যাপ করলে ম্যাপ খোলে এবং রেকর্ডের প্রস্তাব দেয়';

  @override
  String get addRatePlacesHelp =>
      'কমিউনিটির সুবিধায় জায়গা যোগ করুন ও রেটিং দিন';

  @override
  String get n395RiderPois => '395+ রাইডার POI';

  @override
  String get verifiedFuelStationsWorkshops =>
      'যাচাইকৃত জ্বালানি স্টেশন, ওয়ার্কশপ, যন্ত্রাংশের দোকান ও রাইডার ক্যাফে।';

  @override
  String get navigateRecord => 'নেভিগেট ও রেকর্ড';

  @override
  String get opensMapsAppCan =>
      'আপনার ম্যাপ অ্যাপ খোলে, আর চাইলে সাথে সাথে ট্রিপও রেকর্ড করে।';

  @override
  String get riderReviews => 'রাইডার রিভিউ';

  @override
  String get rateOctanePurityMechanic =>
      'অকটেনের খাঁটিত্ব, মেকানিকের সততা ও পার্কিংয়ের নিরাপত্তায় রেটিং দিন।';

  @override
  String get rideTogether => 'একসাথে রাইড';

  @override
  String get ridingCommunityAllOne =>
      'আপনার রাইডিং কমিউনিটি, সবকিছু এক জায়গায়।';

  @override
  String get shareRidesFeedHome =>
      'রাইড ফিডে শেয়ার করুন — বাড়ির অবস্থান লুকানো থাকে';

  @override
  String get startGroupRideWith =>
      '6 অক্ষরের জয়েন কোড দিয়ে গ্রুপ রাইড শুরু করুন';

  @override
  String get pushTalkIntercomBluetooth =>
      'ব্লুটুথ হেলমেটের জন্য পুশ-টু-টক ইন্টারকম';

  @override
  String get bikeModelForumsTalk =>
      'বাইক-মডেল ফোরাম — FZ-S, পালসার ও CBR রাইডারদের সাথে কথা বলুন';

  @override
  String get directMessageAnyRider =>
      'প্ল্যাটফর্মের যেকোনো রাইডারকে সরাসরি মেসেজ করুন';

  @override
  String get privacyZones => 'প্রাইভেসি জোন';

  @override
  String get eachRidesStartEnd =>
      'শেয়ার করার আগে প্রতিটি রাইডের শুরু ও শেষ অংশ কেটে ফেলা হয়।';

  @override
  String get groupPinIntercom => 'গ্রুপ পিন ও ইন্টারকম';

  @override
  String get liveMapTrackingBluetooth =>
      'লাইভ ম্যাপ ট্র্যাকিং ও ব্লুটুথ হেলমেট PTT ইন্টারকম।';

  @override
  String get bikeModelForums => 'বাইক মডেল ফোরাম';

  @override
  String get discussModsIssuesMeets =>
      'আপনার বাইকের মালিকদের সাথে মডিফিকেশন, সমস্যা ও মিটআপ নিয়ে আলোচনা করুন।';

  @override
  String get yourProfile => 'আপনার প্রোফাইল';

  @override
  String get makeItYoursAdd =>
      'নিজের মতো করে সাজান — আলাদা হতে একটি বায়ো যোগ করুন।';

  @override
  String get publicProfileWithStats =>
      'আপনার পরিসংখ্যান ও শেয়ার করা রাইডসহ পাবলিক প্রোফাইল';

  @override
  String get handleLetsOtherRiders =>
      'আপনার @হ্যান্ডেল দিয়ে অন্য রাইডাররা আপনাকে খুঁজে ফলো করতে পারে';

  @override
  String get controlWhoSeesProfile =>
      'কে আপনার প্রোফাইল ও বাইক দেখবে তা নিয়ন্ত্রণ করুন';

  @override
  String get safeqrOfflineEmergencyMedical =>
      'SafeQR: অফলাইনে কাজ করা জরুরি মেডিকেল কার্ড';

  @override
  String get riderStats => 'রাইডার পরিসংখ্যান';

  @override
  String get showcaseTotalKmSafety =>
      'মোট কিমি, সেফটি স্কোর ও সেরা অর্জন তুলে ধরুন।';

  @override
  String get safeqrCard => 'SafeQR কার্ড';

  @override
  String get offlineMedicalCardEmergency =>
      'রাস্তায় জরুরি সহায়তাকারীদের জন্য অফলাইন মেডিকেল কার্ড।';

  @override
  String get keepUp5Contacts =>
      'যোগাযোগের জন্য একজন সহায়তাকারীর কাছে সর্বোচ্চ 5টি কন্টাক্ট রাখুন।';

  @override
  String get thatUsernameTakenTry =>
      'এই ইউজারনেমটি নেওয়া হয়ে গেছে — অন্যটি চেষ্টা করুন।';

  @override
  String errorWithDetail(Object e) {
    return 'ত্রুটি: $e';
  }

  @override
  String get whatShouldWeCall => 'আমরা আপনাকে কী নামে ডাকব?';

  @override
  String get addFirstBike => 'আপনার প্রথম বাইক যোগ করুন';

  @override
  String get nameHandleSoCommunity =>
      'আপনার নাম ও @হ্যান্ডেল, যাতে কমিউনিটি আপনাকে খুঁজে পায়।';

  @override
  String get throttleiqTracksRidesMaintenance =>
      'ThrottleIQ প্রতিটি বাইকের আলাদা করে রাইড ও মেইনটেন্যান্স ট্র্যাক করে।';

  @override
  String get continueAction => 'চালিয়ে যান →';

  @override
  String get addBikeTakeTour => 'বাইক যোগ করে ট্যুর নিন';

  @override
  String get backArrow => '← ফিরে যান';

  @override
  String get skipNow => 'আপাতত এড়িয়ে যান';

  @override
  String get fullName => 'পূর্ণ নাম *';

  @override
  String get eGRahimHossain => 'যেমন: রাহিম হোসেন';

  @override
  String get nameRequired => 'নাম দিতে হবে';

  @override
  String get username => 'ইউজারনেম *';

  @override
  String get lettersNumbersUnderscore3 =>
      'অক্ষর, সংখ্যা, আন্ডারস্কোর · 3–20 অক্ষর';

  @override
  String get n320CharactersLetters => '3–20 অক্ষর: অক্ষর, সংখ্যা, আন্ডারস্কোর';

  @override
  String get brand => 'ব্র্যান্ড *';

  @override
  String get model => 'মডেল *';

  @override
  String get year => 'সাল';

  @override
  String get engineCc => 'ইঞ্জিন সিসি';

  @override
  String get exitDemo => 'ডেমো থেকে বের হোন';

  @override
  String get yourInfo => 'আপনার তথ্য';

  @override
  String get yourBike => 'আপনার বাইক';

  @override
  String get featureTour => 'ফিচার ট্যুর';

  @override
  String get createAccount => 'অ্যাকাউন্ট খুলুন';

  @override
  String get back => 'ফিরে যান';

  @override
  String get joinThrottleiq => 'ThrottleIQ-তে যোগ দিন';

  @override
  String get trackEveryRideRemember =>
      'প্রতিটি রাইড ট্র্যাক করুন, প্রতিটি মাইল মনে রাখুন';

  @override
  String get n6Characters => '6+ অক্ষর';

  @override
  String get min6Characters => 'ন্যূনতম 6 অক্ষর';

  @override
  String get confirmPassword => 'পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get passwordsDoNotMatch => 'পাসওয়ার্ড মিলছে না';

  @override
  String get signUpWithGoogle => 'গুগল দিয়ে সাইন আপ করুন';

  @override
  String get alreadyHaveAccount => 'আগে থেকেই অ্যাকাউন্ট আছে? ';

  @override
  String get rideSmarterTrackDeeper => 'আরও স্মার্ট রাইড। আরও গভীর ট্র্যাকিং।';

  @override
  String guideProgress(Object slideIndex, Object totalSlides) {
    return 'গাইড $slideIndex / $totalSlides';
  }

  @override
  String get skipTour => 'ট্যুর এড়িয়ে যান';

  @override
  String get showMe => 'দেখান';

  @override
  String get getRiding => 'রাইড শুরু করুন 🏍️';

  @override
  String get gotIt => 'বুঝেছি  →';

  @override
  String get myGarage => 'আমার গ্যারেজ';

  @override
  String get addBike => 'বাইক যোগ করুন';

  @override
  String get active => 'সক্রিয়';

  @override
  String get n4280KmLogged => '4,280 কিমি লগ করা হয়েছে';

  @override
  String get oilFilterDue720 => 'তেল ও ফিল্টার বদলাতে বাকি 720 কিমি';

  @override
  String get themeTint => 'থিম টিন্ট:';

  @override
  String get gpsLocked => 'GPS লক হয়েছে';

  @override
  String get avg52 => 'গড় 52 · ';

  @override
  String get top124 => 'সর্বোচ্চ 124';

  @override
  String get distance => 'দূরত্ব';

  @override
  String get moving31m => 'চলমান 31 মি';

  @override
  String get hold1sStart => 'শুরু করতে 1 সেকেন্ড ধরে রাখুন';

  @override
  String get autoTrackingSettings => 'অটো-ট্র্যাকিং সেটিংস';

  @override
  String get smartNonRideFilter => 'স্মার্ট নন-রাইড ফিল্টার চালু';

  @override
  String get walkingBusesSubwayRides =>
      'হাঁটা, বাস ও সাবওয়ে যাত্রা নিজে থেকেই উপেক্ষা করা হয়';

  @override
  String get detectedRide => 'শনাক্ত করা রাইড';

  @override
  String get autoSaved => 'অটো সেভ হয়েছে';

  @override
  String get maintenanceSchedule => 'মেইনটেন্যান্স সূচি';

  @override
  String get logService => '+ সার্ভিস লগ করুন';

  @override
  String get engineOilFilter => 'ইঞ্জিন অয়েল ও ফিল্টার';

  @override
  String get due320Km => '320 কিমি পরে বাকি';

  @override
  String get chainCleanLube => 'চেইন পরিষ্কার ও লুব';

  @override
  String get good850Km => 'আরও 850 কিমি ভালো';

  @override
  String get brakeFluidFlush => 'ব্রেক ফ্লুইড ফ্লাশ';

  @override
  String get good2100Km => 'আরও 2,100 কিমি ভালো';

  @override
  String get n49VerifiedPure => '★ 4.9 · যাচাইকৃত খাঁটি জ্বালানি · 24/7 খোলা';

  @override
  String get directions => 'ডিরেকশনস';

  @override
  String get riderFeed => 'রাইডার ফিড';

  @override
  String get n2hAgo => '2 ঘণ্টা আগে';

  @override
  String get morningTwistiesThrough300 =>
      '300 ফুট হাইওয়ে ধরে সকালের আঁকাবাঁকা পথে রাইড!';

  @override
  String get privacyZone200mEndpoints =>
      'প্রাইভেসি জোন: 200 মিটার শেষ প্রান্ত কাটা হয়েছে';

  @override
  String get roadCaptainDhakaMetro => 'রোড ক্যাপ্টেন · ঢাকা মেট্রো';

  @override
  String get kmRidden => 'কিমি চালানো';

  @override
  String get safetyScore => 'সেফটি স্কোর';

  @override
  String get safeqrOfflineMedicalCard => 'SafeQR অফলাইন মেডিকেল কার্ড';

  @override
  String get bloodOIceEmergency => 'রক্ত: O+ · ICE জরুরি SOS প্রস্তুত';

  @override
  String guideProgressDot(Object slideIndex, Object total) {
    return 'গাইড · $slideIndex / $total';
  }

  @override
  String get backTour => 'ট্যুরে ফিরে যান';

  @override
  String get next => 'পরবর্তী →';

  @override
  String get closeGuide => 'গাইড বন্ধ করুন';

  @override
  String get throttleiqLiveRide => 'ThrottleIQ লাইভ রাইড';

  @override
  String get liveSharingStopped => 'লাইভ শেয়ারিং বন্ধ হয়েছে';

  @override
  String get discardThisRide => 'এই রাইড বাদ দেবেন?';

  @override
  String overWillBeDeleted(Object distance, Object duration) {
    return '$duration সময়ে চালানো $distance মুছে ফেলা হবে। এই রাইড আপনার ইতিহাসে সেভ হবে না এবং আর ফিরিয়ে আনা যাবে না।';
  }

  @override
  String get keepRecording => 'রেকর্ড চালু রাখুন';

  @override
  String get discard => 'বাদ দিন';

  @override
  String get liveSharing => 'লাইভ শেয়ারিং চালু';

  @override
  String get turnShareLiveLocation => 'চালু করে লাইভ লোকেশন শেয়ার করুন';

  @override
  String get distanceLabel => 'দূরত্ব';

  @override
  String get avgSpeed => 'গড় গতি';

  @override
  String get confidence => 'নিশ্চয়তা';

  @override
  String get resume => 'আবার শুরু';

  @override
  String get pause => 'বিরতি';

  @override
  String get endRide => 'রাইড শেষ করুন';

  @override
  String get discardRide => 'রাইড বাদ দিন';

  @override
  String get rideKeptFromLast => 'আগের রাইডটি রাখা হয়েছে';

  @override
  String get resumeCarryDiscardIt =>
      'চালিয়ে যেতে আবার শুরু করুন, অথবা নতুন করে শুরু করতে এটি বাদ দিন।';

  @override
  String get crashDetected => 'দুর্ঘটনা শনাক্ত হয়েছে';

  @override
  String get okEmergencyContactsWill =>
      'আপনি কি ঠিক আছেন? টাইমার শেষ হলে আপনার জরুরি কন্টাক্টদের জানানো হবে।';

  @override
  String get seconds => 'সেকেন্ড';

  @override
  String get imOk => 'আমি ঠিক আছি';

  @override
  String get brakeCaps => 'ব্রেক';

  @override
  String get accelCaps => 'এক্সেল';

  @override
  String get turnOnLocation => 'লোকেশন চালু করুন';

  @override
  String get openAppSettings => 'অ্যাপ সেটিংস খুলুন';

  @override
  String get reportProblem => 'সমস্যা জানান';

  @override
  String get noBikeYet => 'এখনো কোনো বাইক নেই';

  @override
  String get addBikeRideThrottleiq =>
      'আপনার চালানো বাইকটি যোগ করুন, তাহলে ThrottleIQ ট্র্যাকিং শুরু করতে পারবে।';

  @override
  String get addABike => 'বাইক যোগ করুন';

  @override
  String get backgroundLocation => 'ব্যাকগ্রাউন্ড লোকেশন';

  @override
  String get backgroundLocationRationale =>
      'ThrottleIQ রাইড চলাকালীন আপনার লোকেশন ব্যবহার করে রুট, গতি ও দূরত্ব রেকর্ড করে — ফোন লক থাকলে বা পকেটে থাকলেও, যাতে রাইড মাঝপথে কেটে না যায়। পরের স্ক্রিনে \"সব সময় অনুমতি দিন\" লোকেশন অ্যাক্সেস চাওয়া হবে। লোকেশন শুধু আপনার রাইড রেকর্ড করতে ব্যবহার হয় এবং রাইড শেষ করার সাথে সাথেই ট্র্যাকিং বন্ধ হয়ে যায়।';

  @override
  String get notNow => 'এখন নয়';

  @override
  String get continueLabel => 'চালিয়ে যান';

  @override
  String get turnOnCaps => 'চালু করুন';

  @override
  String get settingsCaps => 'সেটিংস';

  @override
  String get slideStartRide => 'রাইড শুরু করতে স্লাইড করুন';

  @override
  String get close => 'বন্ধ করুন';

  @override
  String get fetchingRoute => 'রুট আনা হচ্ছে…';

  @override
  String get routeNotAvailable => 'রুট পাওয়া যায়নি';

  @override
  String get zoomIn => 'জুম ইন';

  @override
  String get zoomOut => 'জুম আউট';

  @override
  String get recenterRoute => 'রুট মাঝখানে আনুন';

  @override
  String get fullscreenMap => 'ফুলস্ক্রিন ম্যাপ';

  @override
  String get rideRecorded => 'রাইড রেকর্ড হয়েছে';

  @override
  String get unknownDate => 'তারিখ অজানা';

  @override
  String get savedCaps => 'সেভ হয়েছে';

  @override
  String get discardedCaps => 'বাদ দেওয়া হয়েছে';

  @override
  String get briefTripNotClassified => 'ছোট ট্রিপ, রাইড হিসেবে গণ্য হয়নি';

  @override
  String get activeHours => 'সক্রিয় সময়';

  @override
  String onlyWatchingRidesBetween(Object startMinutes, Object endMinutes) {
    return 'শুধু $startMinutes থেকে $endMinutes পর্যন্ত রাইড খোঁজা হচ্ছে।';
  }

  @override
  String get watchingRidesAllDay => 'সারা দিন রাইড খোঁজা হচ্ছে।';

  @override
  String get fromLabel => 'শুরু';

  @override
  String get untilLabel => 'শেষ';

  @override
  String get startTimeMustBe => 'শুরুর সময় শেষের সময়ের আগে হতে হবে।';

  @override
  String get endRideQuestion => 'রাইড শেষ করবেন?';

  @override
  String get rideWillBeSaved => 'আপনার রাইড সেভ হবে।';

  @override
  String get shareRideAfterSaving => 'সেভ করার পর রাইড শেয়ার করুন';

  @override
  String get keepRiding => 'রাইড চালিয়ে যান';

  @override
  String get endRidePressHold => 'রাইড শেষ করুন। চেপে ধরে রাখুন।';

  @override
  String get keepHolding => 'ধরে রাখুন…';

  @override
  String get holdEndRide => 'রাইড শেষ করতে ধরে রাখুন';

  @override
  String get startRidePressHold => 'রাইড শুরু করুন। চেপে ধরে রাখুন।';

  @override
  String get goCaps => 'শুরু';

  @override
  String get holdCaps => 'ধরুন';

  @override
  String get recordingNotificationTextUser =>
      'ThrottleIQ ব্যাকগ্রাউন্ডে আপনার রাইড রেকর্ড করছে';

  @override
  String get recordingNotificationTextAuto =>
      'ThrottleIQ একটি রাইড শনাক্ত করেছে এবং রেকর্ড করছে';

  @override
  String get rideRecordingActive => 'রাইড রেকর্ড চলছে';

  @override
  String get rideDetected => 'রাইড শনাক্ত হয়েছে';

  @override
  String get recordingLocationOff =>
      'লোকেশন বন্ধ আছে। রাইড শুরু করতে লোকেশন সার্ভিস চালু করুন।';

  @override
  String get recordingPermissionDenied =>
      'রাইড ট্র্যাক করতে ThrottleIQ-র লোকেশন অনুমতি দরকার। সেটিংসে গিয়ে অনুমতি দিন।';

  @override
  String get addBikeBeforeRecording =>
      'রাইড রেকর্ড করার আগে একটি বাইক যোগ করুন।';

  @override
  String get aRider => 'একজন রাইডার';

  @override
  String livePositionsUnavailable(Object e) {
    return 'লাইভ পজিশন পাওয়া যাচ্ছে না: $e';
  }

  @override
  String get locationPermissionOffGroup =>
      'লোকেশন অনুমতি বন্ধ — গ্রুপ আপনাকে দেখতে পাচ্ছে না। আপনি তাদের দেখতে পাচ্ছেন।';

  @override
  String locationUnavailable(Object e) {
    return 'লোকেশন পাওয়া যাচ্ছে না: $e';
  }

  @override
  String get leaveGroupRide => 'গ্রুপ রাইড ছেড়ে যাবেন?';

  @override
  String get othersStopSeeingPosition =>
      'অন্যরা আর আপনার অবস্থান দেখতে পাবে না। আপনার নিজের রাইড রেকর্ডিং চলতেই থাকবে — রাইড স্ক্রিন থেকে সেটি শেষ করুন।';

  @override
  String get stay => 'থাকুন';

  @override
  String get leave => 'ছেড়ে যান';

  @override
  String couldntLeave(Object e) {
    return 'ছেড়ে যাওয়া যায়নি: $e';
  }

  @override
  String get microphoneAccessOffCan =>
      'মাইক্রোফোন বন্ধ আছে — আপনি এখনও গ্রুপের কথা শুনতে পাবেন।';

  @override
  String couldntStartRecording(Object e) {
    return 'রেকর্ডিং শুরু করা যায়নি: $e';
  }

  @override
  String couldntSendVoiceNote(Object e) {
    return 'ভয়েস নোট পাঠানো যায়নি: $e';
  }

  @override
  String get groupRide => 'গ্রুপ রাইড';

  @override
  String get thisGroupRideNo => 'এই গ্রুপ রাইডটি আর নেই।';

  @override
  String get recordingReleaseSend => 'রেকর্ড হচ্ছে — পাঠাতে ছেড়ে দিন';

  @override
  String playing(Object note) {
    return '$note চলছে…';
  }

  @override
  String get holdTalk => 'কথা বলতে ধরে রাখুন';

  @override
  String get unmuteVoiceNotes => 'ভয়েস নোট আনমিউট করুন';

  @override
  String get muteVoiceNotes => 'ভয়েস নোট মিউট করুন';

  @override
  String get nobodyThisRideYet => 'এই রাইডে এখনো কেউ নেই।';

  @override
  String ridingJoined(Object joinedCount) {
    return 'রাইডে আছেন — $joinedCount';
  }

  @override
  String invitedWaiting(Object pendingCount) {
    return 'আমন্ত্রিত — $pendingCount জন অপেক্ষায়';
  }

  @override
  String get hasntJoinedYet => 'এখনো যোগ দেননি';

  @override
  String you(Object userName) {
    return '$userName (আপনি)';
  }

  @override
  String get waitingFirstPosition => 'প্রথম অবস্থানের অপেক্ষায়…';

  @override
  String get deleteSharedRide => 'শেয়ার করা রাইড মুছবেন?';

  @override
  String get thisRemovesItFrom =>
      'এতে সবার ফিড থেকে এটি সরে যাবে। আপনার ফোনের রাইড ইতিহাস অপরিবর্তিত থাকবে।';

  @override
  String get delete => 'মুছুন';

  @override
  String get mySharedRides => 'আমার শেয়ার করা রাইড';

  @override
  String get haventSharedAnyRides => 'আপনি এখনো কোনো রাইড শেয়ার করেননি';

  @override
  String get notifications => 'নোটিফিকেশন';

  @override
  String get noNotificationsYet => 'এখনো কোনো নোটিফিকেশন নেই';

  @override
  String couldntJoinRide(Object e) {
    return 'রাইডে যোগ দেওয়া যায়নি: $e';
  }

  @override
  String tapJoin(Object relativeTime) {
    return '$relativeTime · যোগ দিতে ট্যাপ করুন';
  }

  @override
  String get anyoneThrottleiq => 'ThrottleIQ-র যে কেউ';

  @override
  String get peopleWhoFollow => 'যারা আপনাকে ফলো করে';

  @override
  String get ridersFollowEachOther => 'যাদের সাথে আপনারা পরস্পরকে ফলো করেন';

  @override
  String canAddUpPhotos(Object maxRidePhotos) {
    return 'আপনি সর্বোচ্চ $maxRidePhotosটি ছবি যোগ করতে পারবেন। আরেকটি যোগ করতে একটি সরিয়ে দিন।';
  }

  @override
  String onlyPhotosPerRide(Object maxRidePhotos, Object remaining) {
    return 'প্রতি রাইডে শুধু $maxRidePhotosটি ছবি — প্রথম $remainingটি রাখা হয়েছে।';
  }

  @override
  String get rideShared => 'রাইড শেয়ার হয়েছে';

  @override
  String get savedWellPostIt => 'সেভ হয়েছে — অনলাইনে ফিরলে আমরা পোস্ট করে দেব';

  @override
  String failedShareRide(Object e) {
    return 'রাইড শেয়ার করা যায়নি: $e';
  }

  @override
  String addUpRideBike(Object maxRidePhotos) {
    return 'রাইড বা বাইকের সর্বোচ্চ $maxRidePhotosটি ছবি যোগ করুন';
  }

  @override
  String get shareRide => 'রাইড শেয়ার করুন';

  @override
  String get saySomethingAboutThis => 'এই রাইড নিয়ে কিছু লিখুন';

  @override
  String get photosOptional => 'ছবি (ঐচ্ছিক)';

  @override
  String get whoCanSeeThis => 'কে এটি দেখতে পাবে';

  @override
  String get saveAsRoute => 'রুট হিসেবে সেভ করুন';

  @override
  String get routeSavedMyRoutes => 'রুটটি আমার রুটে সেভ হয়েছে!';

  @override
  String failedPostComment(Object e) {
    return 'কমেন্ট পোস্ট করা যায়নি: $e';
  }

  @override
  String voteFailed(Object e) {
    return 'ভোট দেওয়া যায়নি: $e';
  }

  @override
  String couldNotSaveRoute(Object e) {
    return 'রুট সেভ করা যায়নি: $e';
  }

  @override
  String get rideDetails => 'রাইডের বিবরণ';

  @override
  String get rideNotFoundRemoved => 'রাইড পাওয়া যায়নি অথবা সরানো হয়েছে';

  @override
  String get reportRide => 'রাইড রিপোর্ট করুন';

  @override
  String get noGpsTrackAvailable => 'এই রাইডের কোনো GPS ট্র্যাক নেই';

  @override
  String get speedPerformanceDetails => 'গতি ও পারফরম্যান্সের বিবরণ';

  @override
  String get maxSpeed => 'সর্বোচ্চ গতি';

  @override
  String get duration => 'সময়কাল';

  @override
  String get ridingPace => 'রাইডিং পেস';

  @override
  String trackPoints(Object polylineCount) {
    return '$polylineCountটি ট্র্যাক পয়েন্ট';
  }

  @override
  String get startColon => 'শুরু: ';

  @override
  String get finishColon => 'শেষ: ';

  @override
  String get ridePhotos => 'রাইডের ছবি';

  @override
  String get upvote => 'আপভোট';

  @override
  String get downvote => 'ডাউনভোট';

  @override
  String commentsCount(Object comments) {
    return '$commentsটি কমেন্ট';
  }

  @override
  String get noCommentsYetBe =>
      'এখনো কোনো কমেন্ট নেই। প্রথম কমেন্টটি আপনিই করুন!';

  @override
  String get addComment => 'কমেন্ট লিখুন...';

  @override
  String get send => 'পাঠান';

  @override
  String get searchRidersForums => 'রাইডার ও ফোরাম খুঁজুন';

  @override
  String get messages => 'মেসেজ';

  @override
  String get feed => 'ফিড';

  @override
  String get forums => 'ফোরাম';

  @override
  String nothingFoundTryUsername(Object query) {
    return '\"$query\" এর জন্য কিছু পাওয়া যায়নি।\\n@ইউজারনেম, ইমেইল বা ফোরামের নাম দিয়ে চেষ্টা করুন।';
  }

  @override
  String couldntSearchRiders(Object error) {
    return 'রাইডার খোঁজা যায়নি: $error';
  }

  @override
  String get noRidersMatchThat => 'এমন কোনো রাইডার নেই।';

  @override
  String couldntSearchForums(Object error) {
    return 'ফোরাম খোঁজা যায়নি: $error';
  }

  @override
  String get noForumsMatchThat => 'এমন কোনো ফোরাম নেই।';

  @override
  String followersPosts(Object followerCount, Object postCount) {
    return '$followerCount ফলোয়ার · $postCountটি পোস্ট';
  }

  @override
  String get nothingFromRidersYet => 'আপনার রাইডারদের কাছ থেকে এখনো কিছু নেই';

  @override
  String get noRidesYet => 'এখনো কোনো রাইড নেই';

  @override
  String get searchRidersAboveFollow =>
      'এটি ভরাতে উপরে রাইডার খুঁজে তাদের ফলো করুন।';

  @override
  String get shareRideFromIts =>
      'শুরু করতে রাইডের সারসংক্ষেপ স্ক্রিন থেকে একটি রাইড শেয়ার করুন।';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String get youreAllCaughtUp => 'সবকিছু দেখা হয়ে গেছে';

  @override
  String get details => 'বিবরণ';

  @override
  String get noCommentsYet => 'এখনো কোনো কমেন্ট নেই';

  @override
  String get following => 'ফলো করছেন';

  @override
  String get follow => 'ফলো করুন';

  @override
  String get rideWithFriends => 'বন্ধুদের সাথে রাইড';

  @override
  String selectedCount(Object selectedCount, Object maxGroupRideFriends) {
    return '$selectedCount/$maxGroupRideFriends জন নির্বাচিত';
  }

  @override
  String pickRidersRideStarts(
      Object minGroupRideFriends, Object maxGroupRideFriends) {
    return '$minGroupRideFriends–$maxGroupRideFriends জন রাইডার বেছে নিন। আপনার রাইড সাথে সাথেই রেকর্ড শুরু করবে; তারা নোটিফিকেশন থেকে যোগ দেবে।';
  }

  @override
  String get usernameEmail => '@ইউজারনেম বা ইমেইল';

  @override
  String get startGroupRide => 'গ্রুপ রাইড শুরু করুন';

  @override
  String startGroupRideWithCount(Object selectedCount) {
    return '$selectedCount জনকে নিয়ে গ্রুপ রাইড শুরু করুন';
  }

  @override
  String get searchByUsernameEmail => '@ইউজারনেম বা ইমেইল দিয়ে খুঁজুন';

  @override
  String get noRidersFound => 'কোনো রাইডার পাওয়া যায়নি';

  @override
  String inviterGroupRide(Object inviterName) {
    return '$inviterName-এর গ্রুপ রাইড';
  }

  @override
  String couldntStartGroupRide(Object e) {
    return 'গ্রুপ রাইড শুরু করা যায়নি: $e';
  }

  @override
  String get signCreateForum => 'ফোরাম তৈরি করতে সাইন ইন করুন।';

  @override
  String couldNotCreateForum(Object e) {
    return 'ফোরাম তৈরি করা যায়নি: $e';
  }

  @override
  String get createForum => 'একটি ফোরাম তৈরি করুন';

  @override
  String get eGSundayBreakfast => 'যেমন: রবিবারের ব্রেকফাস্ট রাইড';

  @override
  String get descriptionOptional => 'বিবরণ (ঐচ্ছিক)';

  @override
  String get whatsThisForumAbout => 'এই ফোরাম কী নিয়ে?';

  @override
  String get youllBeAbleModerate =>
      'এখানে আপনি পোস্ট মডারেট করতে পারবেন এবং অন্য রাইডারদের মেইনটেইনার হিসেবে যোগ করতে পারবেন।';

  @override
  String get create => 'তৈরি করুন';

  @override
  String failedPostReply(Object e) {
    return 'রিপ্লাই পোস্ট করা যায়নি: $e';
  }

  @override
  String get post => 'পোস্ট';

  @override
  String get postNotFound => 'পোস্ট পাওয়া যায়নি';

  @override
  String get noRepliesYetBe =>
      'এখনো কোনো রিপ্লাই নেই — প্রথম সাহায্যকারী আপনিই হোন।';

  @override
  String get writeReply => 'রিপ্লাই লিখুন...';

  @override
  String get forum => 'ফোরাম';

  @override
  String get unfollow => 'আনফলো করুন';

  @override
  String get manageMaintainers => 'মেইনটেইনার পরিচালনা করুন';

  @override
  String get newPost => 'নতুন পোস্ট';

  @override
  String get noPostsYet => 'এখনো কোনো পোস্ট নেই';

  @override
  String get beFirstAskQuestion => 'প্রথম প্রশ্নটি করুন বা কিছু শেয়ার করুন।';

  @override
  String get title => 'শিরোনাম';

  @override
  String get titleRequired => 'শিরোনাম দিতে হবে';

  @override
  String get whatsGoing => 'কী হচ্ছে?';

  @override
  String get saySomethingBeforePosting => 'পোস্ট করার আগে কিছু লিখুন';

  @override
  String get couldntRecordVoteCheck =>
      'আপনার ভোট রেকর্ড করা যায়নি — সংযোগ দেখে আবার চেষ্টা করুন।';

  @override
  String get deletePostQuestion => 'পোস্ট মুছবেন?';

  @override
  String get thisRemovesPostIts =>
      'এতে ফোরাম থেকে পোস্ট ও তার সব রিপ্লাই মুছে যাবে। এটি আর ফিরিয়ে আনা যাবে না।';

  @override
  String couldNotDelete(Object e) {
    return 'মুছে ফেলা যায়নি: $e';
  }

  @override
  String get deletePost => 'পোস্ট মুছুন';

  @override
  String get reportPost => 'পোস্ট রিপোর্ট করুন';

  @override
  String fromUser(Object displayName) {
    return '$displayName এর কাছ থেকে';
  }

  @override
  String couldNotUpdateMaintainers(Object e) {
    return 'মেইনটেইনার হালনাগাদ করা যায়নি: $e';
  }

  @override
  String get maintainers => 'মেইনটেইনার';

  @override
  String get maintainersCanDeletePosts =>
      'মেইনটেইনাররা এই ফোরামের পোস্ট ও রিপ্লাই মুছতে পারেন।';

  @override
  String get noMaintainersYet => 'এখনো কোনো মেইনটেইনার নেই।';

  @override
  String get remove => 'সরিয়ে দিন';

  @override
  String get addByRiderUid => 'রাইডার UID দিয়ে যোগ করুন';

  @override
  String couldNotOpenForum(Object e) {
    return 'ফোরাম খোলা যায়নি: $e';
  }

  @override
  String get yourBikes => 'আপনার বাইক';

  @override
  String get addBikeGarageSee =>
      'এখানে বাইকের ফোরাম দেখতে আপনার গ্যারেজে একটি বাইক যোগ করুন।';

  @override
  String get riderForums => 'রাইডার ফোরাম';

  @override
  String get noRiderMadeForums =>
      'এখনো কোনো রাইডার-তৈরি ফোরাম নেই। প্রথমটি আপনিই তৈরি করুন।';

  @override
  String get findForum => 'ফোরাম খুঁজুন';

  @override
  String get searchBrandEG => 'ব্র্যান্ড খুঁজুন, যেমন Yamaha';

  @override
  String get searchForums => 'ফোরাম খুঁজুন';

  @override
  String get brands => 'ব্র্যান্ড';

  @override
  String get topics => 'বিষয়';

  @override
  String postsFollowers(Object postCount, Object followerCount) {
    return '$postCountটি পোস্ট · $followerCount ফলোয়ার';
  }

  @override
  String get notificationSettings => 'নোটিফিকেশন সেটিংস';

  @override
  String get newMessage => 'নতুন মেসেজ';

  @override
  String get newMessageTitle => 'নতুন মেসেজ';

  @override
  String get noMessagesYet => 'এখনো কোনো মেসেজ নেই';

  @override
  String get startConversation => 'কথোপকথন শুরু করুন';

  @override
  String get loading => 'লোড হচ্ছে...';

  @override
  String get sayHi => 'হাই বলুন!';

  @override
  String get searchRiderByUsername =>
      '@ইউজারনেম বা ইমেইল দিয়ে রাইডার খুঁজুন...';

  @override
  String noRidersFoundFor(Object text) {
    return '\"$text\" এর জন্য কোনো রাইডার পাওয়া যায়নি';
  }

  @override
  String get retry => 'আবার চেষ্টা';

  @override
  String get chat => 'চ্যাট';

  @override
  String get cantMessageThisRider => 'আপনি এই রাইডারকে মেসেজ করতে পারবেন না';

  @override
  String get messageHint => 'মেসেজ...';

  @override
  String get spamMisleading => 'স্প্যাম বা বিভ্রান্তিকর';

  @override
  String get harassmentBullying => 'হয়রানি বা বুলিং';

  @override
  String get hateSpeech => 'ঘৃণামূলক বক্তব্য';

  @override
  String get inappropriateContent => 'অনুপযুক্ত কনটেন্ট';

  @override
  String get reportSubmittedSuccessfullyWe =>
      'রিপোর্ট সফলভাবে জমা হয়েছে। আমরা শীঘ্রই এটি পর্যালোচনা করব।';

  @override
  String failedSubmitReport(Object e) {
    return 'রিপোর্ট জমা দেওয়া যায়নি: $e';
  }

  @override
  String get report => 'রিপোর্ট';

  @override
  String get whyReportingThis => 'কেন এটি রিপোর্ট করছেন?';

  @override
  String get additionalDetailsOptional => 'অতিরিক্ত বিবরণ (ঐচ্ছিক)';

  @override
  String get submitReport => 'রিপোর্ট জমা দিন';

  @override
  String get audiencePublic => 'পাবলিক';

  @override
  String get audienceFollowers => 'ফলোয়ার';

  @override
  String get audienceMutual => 'পারস্পরিক';

  @override
  String get selfHarm => 'নিজের ক্ষতি করা';

  @override
  String get otherReason => 'অন্যান্য';

  @override
  String followMyRideLive(String url) {
    return 'আমার রাইড লাইভ অনুসরণ করুন: $url';
  }
}
