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
  String get hold1sRecord => 'রেকর্ড করতে ১ সেকেন্ড ধরে রাখুন';

  @override
  String get hold1sStartStop =>
      'শুরু বা শেষ করতে ১ সেকেন্ড ধরে রাখুন; ভুলে ছোঁয়া থেকে রক্ষা করে।';

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
  String get n13ServiceItems => '১৩+ সার্ভিস আইটেম';

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
  String get n395RiderPois => '৩৯৫+ রাইডার POI';

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
      '৬ অক্ষরের জয়েন কোড দিয়ে গ্রুপ রাইড শুরু করুন';

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
      'যোগাযোগের জন্য একজন সহায়তাকারীর কাছে সর্বোচ্চ ৫টি কন্টাক্ট রাখুন।';

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
      'অক্ষর, সংখ্যা, আন্ডারস্কোর · ৩–২০ অক্ষর';

  @override
  String get n320CharactersLetters => '৩–২০ অক্ষর: অক্ষর, সংখ্যা, আন্ডারস্কোর';

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
  String get n6Characters => '৬+ অক্ষর';

  @override
  String get min6Characters => 'ন্যূনতম ৬ অক্ষর';

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
  String get n4280KmLogged => '৪,২৮০ কিমি লগ করা হয়েছে';

  @override
  String get oilFilterDue720 => 'তেল ও ফিল্টার বদলাতে বাকি ৭২০ কিমি';

  @override
  String get themeTint => 'থিম টিন্ট:';

  @override
  String get gpsLocked => 'GPS লক হয়েছে';

  @override
  String get avg52 => 'গড় ৫২ · ';

  @override
  String get top124 => 'সর্বোচ্চ ১২৪';

  @override
  String get distance => 'দূরত্ব';

  @override
  String get moving31m => 'চলমান ৩১ মি';

  @override
  String get hold1sStart => 'শুরু করতে ১ সেকেন্ড ধরে রাখুন';

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
  String get due320Km => '৩২০ কিমি পরে বাকি';

  @override
  String get chainCleanLube => 'চেইন পরিষ্কার ও লুব';

  @override
  String get good850Km => 'আরও ৮৫০ কিমি ভালো';

  @override
  String get brakeFluidFlush => 'ব্রেক ফ্লুইড ফ্লাশ';

  @override
  String get good2100Km => 'আরও ২,১০০ কিমি ভালো';

  @override
  String get n49VerifiedPure => '★ ৪.৯ · যাচাইকৃত খাঁটি জ্বালানি · ২৪/৭ খোলা';

  @override
  String get directions => 'ডিরেকশনস';

  @override
  String get riderFeed => 'রাইডার ফিড';

  @override
  String get n2hAgo => '২ ঘণ্টা আগে';

  @override
  String get morningTwistiesThrough300 =>
      '৩০০ ফুট হাইওয়ে ধরে সকালের আঁকাবাঁকা পথে রাইড!';

  @override
  String get privacyZone200mEndpoints =>
      'প্রাইভেসি জোন: ২০০ মিটার শেষ প্রান্ত কাটা হয়েছে';

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
}
