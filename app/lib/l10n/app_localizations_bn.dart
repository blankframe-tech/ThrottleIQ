// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get suggestedForYou => 'আপনার জন্য প্রস্তাবিত';

  @override
  String get showMore => 'আরও দেখুন';

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
  String get themeSportLabel => 'স্পোর্ট';

  @override
  String get themeSportDescription => 'লাইম আর ম্যাজেন্টা, কার্বন প্যানেল';

  @override
  String get themeRainLabel => 'রেইন';

  @override
  String get themeRainDescription => 'গাঢ় নীল সন্ধ্যা, বেগুনি আর টিল';

  @override
  String get themeRaceLabel => 'রেস';

  @override
  String get themeRaceDescription => 'রেস পোস্টার, সরিষা ও মরিচা রং';

  @override
  String get themeCommuteLabel => 'কমিউট';

  @override
  String get themeCommuteDescription => 'শান্ত ক্রিম, সবুজ আর বাদামি';

  @override
  String get themeTourLabel => 'ট্যুর';

  @override
  String get themeTourDescription => 'ঝলমলে কমলা আর আকাশি নীল';

  @override
  String get themeAdvLabel => 'এডিভি';

  @override
  String get themeAdvDescription => 'নেভি কনসোল, সায়ান মিটার';

  @override
  String get themeCityLabel => 'সিটি';

  @override
  String get themeCityDescription => 'কাগজের উষ্ণতা, নীল আর কমলা';

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
  String get shareRideCodeButtonTooltip => 'রাইড কোড শেয়ার করুন';

  @override
  String get shareRideCodeTitle => 'এই রাইডের কোড শেয়ার করুন';

  @override
  String get shareRideCodeSubtitle =>
      'রাইড সক্রিয় থাকা অবস্থায় এই কোড দিয়ে যে কেউ যোগ দিতে পারবে।';

  @override
  String get shareRideCodeCopyAction => 'কোড কপি করুন';

  @override
  String get shareRideCodeShareAction => 'শেয়ার করুন';

  @override
  String get shareRideCodeCopied => 'কোড ক্লিপবোর্ডে কপি হয়েছে';

  @override
  String shareRideCodeMessage(Object rideName, Object code) {
    return 'আমার ThrottleIQ রাইড \"$rideName\"-এ যোগ দিন — যোগ দিতে কোড $code ব্যবহার করুন!';
  }

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
  String get myQrTitle => 'আমার QR কোড';

  @override
  String get myQrIntro =>
      'যে রাইডাররা এই কোড স্ক্যান করবেন, তাঁরা আপনাকে ফলো করবেন। ThrottleIQ-এর স্ক্যানার বা যেকোনো ফোনের ক্যামেরায় কাজ করে।';

  @override
  String get myQrShareAction => 'শেয়ার করুন';

  @override
  String get myQrSaveAction => 'ছবি সেভ করুন';

  @override
  String myQrShareText(String link) {
    return 'ThrottleIQ-এ আমাকে ফলো করুন: $link';
  }

  @override
  String get myQrSaved => 'QR কোড আপনার ফটোতে সেভ হয়েছে।';

  @override
  String get myQrSaveNoAccess =>
      'ThrottleIQ আপনার ফটোতে সেভ করতে পারছে না। সেটিংসে ফটো অ্যাক্সেস চালু করুন।';

  @override
  String get myQrImageFailed => 'আপনার QR কোডের ছবি তৈরি করা যায়নি।';

  @override
  String get scanQrAction => 'QR স্ক্যান করুন';

  @override
  String get scanQrTitle => 'রাইডারের QR স্ক্যান করুন';

  @override
  String get scanQrHint =>
      'অন্য রাইডারকে ফলো করতে তাঁর ThrottleIQ QR কোডের দিকে ক্যামেরা ধরুন।';

  @override
  String get scanQrTorch => 'ফ্ল্যাশলাইট';

  @override
  String get scanQrCameraDenied =>
      'ক্যামেরা অ্যাক্সেস বন্ধ। QR কোড স্ক্যান করতে সেটিংসে এটি চালু করুন।';

  @override
  String get scanQrCameraError => 'ক্যামেরা চালু হয়নি।';

  @override
  String followLinkFollowed(String name) {
    return 'আপনি এখন $name-কে ফলো করছেন।';
  }

  @override
  String followLinkAlreadyFollowing(String name) {
    return 'আপনি আগে থেকেই $name-কে ফলো করছেন।';
  }

  @override
  String get followLinkSelf => 'এটি আপনার নিজের QR কোড।';

  @override
  String get followLinkInvalid => 'এটি ThrottleIQ রাইডারের কোড নয়।';

  @override
  String get followLinkSignInFirst =>
      'এই রাইডারকে ফলো করা শেষ করতে সাইন ইন করুন।';

  @override
  String get followLinkFailed =>
      'এই রাইডারকে ফলো করা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

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
  String get startRide => 'রাইড শুরু করুন';

  @override
  String get autoTracking => 'অটো ট্র্যাকিং';

  @override
  String get maintenance => 'মেইনটেন্যান্স';

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
  String get skipTour => 'ট্যুর এড়িয়ে যান';

  @override
  String get addBike => 'বাইক যোগ করুন';

  @override
  String get active => 'সক্রিয়';

  @override
  String get distance => 'দূরত্ব';

  @override
  String get directions => 'ডিরেকশনস';

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
  String get recordingStartFailed => 'রাইড শুরু করা যায়নি। আবার চেষ্টা করুন।';

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
  String tapView(Object relativeTime) {
    return '$relativeTime · দেখতে ট্যাপ করুন';
  }

  @override
  String get anyoneThrottleiq => 'ThrottleIQ-র যে কেউ';

  @override
  String get peopleWhoFollow =>
      'পরে যারা ফলো করবে তারাও দেখতে পাবে। ফলো করতে আপনার অনুমতি লাগে না।';

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
  String get sharePreviewLabel => 'যেমন দেখাবে';

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
  String get peopleTabLabel => 'মানুষ';

  @override
  String get ridingNowSectionTitle => 'এখন রাইডে আছেন';

  @override
  String get searchRidersHint => 'নাম বা @ইউজারনেম দিয়ে রাইডার খুঁজুন';

  @override
  String get notFollowingAnyoneYet =>
      'আপনি এখনো কাউকে ফলো করছেন না। রাইডার খুঁজতে উপরে সার্চ করুন।';

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

  @override
  String get logServiceTitle => 'সার্ভিস লগ করুন';

  @override
  String get serviceType => 'সার্ভিসের ধরন';

  @override
  String get whatDidService => 'কী সার্ভিস করালেন? *';

  @override
  String get eGRadiatorFlush => 'যেমন: রেডিয়েটর ফ্লাশ';

  @override
  String get nameService => 'সার্ভিসের নাম দিন';

  @override
  String get odometerKm => 'ওডোমিটার (কিমি) *';

  @override
  String get requiredField => 'আবশ্যক';

  @override
  String get invalidNumber => 'সংখ্যাটি সঠিক নয়';

  @override
  String get odometerSyncFailed =>
      'ওডোমিটার সিঙ্ক করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get visitSaveFailed => 'ভিজিট সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get costOptional => 'খরচ (ঐচ্ছিক)';

  @override
  String get notesOptional => 'নোট (ঐচ্ছিক)';

  @override
  String configuredSpec(Object specNote) {
    return 'নির্ধারিত স্পেক: $specNote';
  }

  @override
  String get eGOctane95 => 'যেমন: অকটেন 95, 12 লিটার ফিল-আপ, যমুনা অয়েল...';

  @override
  String get eGUsedMotul => 'যেমন: Motul 10W40 ব্যবহার করেছি...';

  @override
  String insertSpec(Object specNote) {
    return 'স্পেক যোগ করুন: $specNote';
  }

  @override
  String get saveServiceLog => 'সার্ভিস লগ সেভ করুন';

  @override
  String get yourMotorcycle => 'আপনার মোটরসাইকেল';

  @override
  String get setupMaintenance => 'মেইনটেন্যান্স সেটআপ';

  @override
  String get editTrackedChecks => 'ট্র্যাক করা চেক সম্পাদনা';

  @override
  String get skip => 'এড়িয়ে যান';

  @override
  String whatWouldLikeTrack(Object bikeName) {
    return '$bikeName-এর জন্য কী কী ট্র্যাক করতে চান?';
  }

  @override
  String get selectComponentsWantThrottleiq =>
      'যেসব যন্ত্রাংশ ThrottleIQ নজরে রাখবে সেগুলো বেছে নিন। আপনার ওডোমিটার দেখে আমরা ক্ষয় হিসাব করব এবং সার্ভিসের সময় হওয়ার আগে জানিয়ে দেব।';

  @override
  String get recommended => 'প্রস্তাবিত';

  @override
  String get selectAll => 'সব বেছে নিন';

  @override
  String get clear => 'পরিষ্কার করুন';

  @override
  String trackChecks(Object enabledCount) {
    return '$enabledCountটি চেক ট্র্যাক করুন';
  }

  @override
  String get savePreferences => 'পছন্দ সেভ করুন';

  @override
  String activeInCategory(Object activeInCategory, Object categoryItemsCount) {
    return '$categoryItemsCountটির মধ্যে $activeInCategoryটি সক্রিয়';
  }

  @override
  String get noActiveBike => 'কোনো সক্রিয় বাইক নেই';

  @override
  String get addMotorcycleGarageTrack =>
      'মেইনটেন্যান্স ট্র্যাক করতে আপনার গ্যারেজে একটি মোটরসাইকেল যোগ করুন।';

  @override
  String get syncOdo => 'ওডো সিঙ্ক';

  @override
  String get customize => 'কাস্টমাইজ';

  @override
  String get log => 'লগ';

  @override
  String get resetServiceLog => 'সার্ভিস লগ রিসেট';

  @override
  String get trackedChecks => 'ট্র্যাক করা চেক';

  @override
  String monitored(Object remindersCount) {
    return '$remindersCountটি নজরে আছে';
  }

  @override
  String filterAll(Object remindersCount) {
    return 'সব ($remindersCount)';
  }

  @override
  String filterAttention(Object attentionCount) {
    return 'মনোযোগ দরকার ($attentionCount)';
  }

  @override
  String filterOk(Object okCount) {
    return 'ঠিক আছে ($okCount)';
  }

  @override
  String get noChecksTrackedYet =>
      'এখনো কোনো চেক ট্র্যাক করা হচ্ছে না। চেক বেছে নিতে উপরের \"কাস্টমাইজ\" ট্যাপ করুন।';

  @override
  String get noChecksMatchingThis => 'এই ফিল্টারের সাথে মেলে এমন কোনো চেক নেই।';

  @override
  String get serviceHistory => 'সার্ভিসের ইতিহাস';

  @override
  String total(Object totalCost) {
    return 'মোট: ৳$totalCost';
  }

  @override
  String get noServiceRecordsLogged => 'এখনো কোনো সার্ভিস রেকর্ড নেই।';

  @override
  String get whenServiceBikeLog =>
      'বাইক সার্ভিস করালে এখানে লগ করুন, ইন্টারভাল রিসেট হয়ে যাবে।';

  @override
  String get switchBike => 'বাইক বদলান';

  @override
  String get switchAction => 'বদলান';

  @override
  String get immediateMaintenanceAttentionRecommended =>
      'এখনই মেইনটেন্যান্স দরকার';

  @override
  String get upcomingScheduledMaintenance => 'আসন্ন নির্ধারিত মেইনটেন্যান্স';

  @override
  String get allSystemsNominal => 'সবকিছু স্বাভাবিক';

  @override
  String allTrackedComponentsGood(Object total) {
    return 'ট্র্যাক করা সব $totalটি যন্ত্রাংশ ভালো অবস্থায় আছে';
  }

  @override
  String get dueSoonTitle => 'শীঘ্রই বাকি';

  @override
  String get whatWouldLikeMaintain => 'কী কী মেইনটেইন করতে চান?';

  @override
  String notEveryoneWantsTrack(Object displayName) {
    return 'সবাই সবকিছু ট্র্যাক করতে চান না। $displayName-এর জন্য যেগুলো আপনার দরকার সেগুলো বেছে নিন, অথবা ট্যাপ করে ইন্টারভাল বদলান ও স্পেক (তেলের ব্র্যান্ড, টায়ারের তারিখ/সাইজ) যোগ করুন:';
  }

  @override
  String get essentials4 => 'জরুরি (4)';

  @override
  String get all8Items => 'সব 8টি আইটেম';

  @override
  String get savingPreferences => 'পছন্দ সেভ হচ্ছে...';

  @override
  String startTrackingItems(Object enabledCount) {
    return 'ট্র্যাকিং শুরু করুন ($enabledCountটি আইটেম)';
  }

  @override
  String get seeAll20Checks => '20+ চেক ও অ্যাডভান্সড সেটআপ দেখুন';

  @override
  String get dueSoon => 'শীঘ্রই বাকি';

  @override
  String intervalEvery(Object imperial) {
    return 'প্রতি $imperial';
  }

  @override
  String lastDone(Object lastServiceDate) {
    return 'সর্বশেষ করা হয়েছে: $lastServiceDate';
  }

  @override
  String get noPreviousServiceRecorded => 'আগের কোনো সার্ভিস রেকর্ড নেই';

  @override
  String get edit => 'সম্পাদনা';

  @override
  String get deleteLog => 'লগ মুছুন';

  @override
  String sureWantDeleteThis(Object displayLabel) {
    return 'আপনি কি নিশ্চিত যে এই $displayLabel রেকর্ডটি মুছে ফেলতে চান?';
  }

  @override
  String get trackDashboard => 'ড্যাশবোর্ডে ট্র্যাক করুন';

  @override
  String get calculateWearMonitorInterval =>
      'ক্ষয় হিসাব করুন ও ইন্টারভাল নজরে রাখুন';

  @override
  String get serviceInterval => 'সার্ভিস ইন্টারভাল';

  @override
  String get intervalDistanceKm => 'ইন্টারভালের দূরত্ব (কিমি)';

  @override
  String get enterPositiveNumber => 'ধনাত্মক সংখ্যা দিন';

  @override
  String get specificationsExtraInfo => 'স্পেসিফিকেশন ও অতিরিক্ত তথ্য';

  @override
  String get optionalText => 'ঐচ্ছিক লেখা';

  @override
  String get specsOilGradeTyre =>
      'স্পেক (তেলের গ্রেড, টায়ারের সাইজ ও তারিখ...)';

  @override
  String get visibleMaintenanceCardQuick =>
      'দ্রুত দেখার জন্য আপনার মেইনটেন্যান্স কার্ডে দেখানো হবে।';

  @override
  String odometerSyncedKm(Object newKm) {
    return 'ওডোমিটার $newKm কিমিতে সিঙ্ক হয়েছে!';
  }

  @override
  String get syncOdometer => 'ওডোমিটার সিঙ্ক';

  @override
  String alignThrottleiqWith(Object displayName) {
    return 'ThrottleIQ-কে $displayName-এর সাথে মেলান';
  }

  @override
  String get rodeOfflineWithoutPhone =>
      'অফলাইনে বা ফোন ট্র্যাকিং ছাড়া চালিয়েছেন? আপনার বাইকের ড্যাশবোর্ড/স্পিডোমিটারের ছবি তুলুন বা নিচে বর্তমান রিডিং লিখুন।';

  @override
  String get scanningInstrumentCluster =>
      'ইন্সট্রুমেন্ট ক্লাস্টার স্ক্যান হচ্ছে...';

  @override
  String get takePhoto => 'ছবি তুলুন';

  @override
  String get fromPhotos => 'ছবি থেকে নিন';

  @override
  String get currentAppOdometer => 'অ্যাপের বর্তমান ওডোমিটার:';

  @override
  String get physicalInstrumentClusterReading =>
      'ইন্সট্রুমেন্ট ক্লাস্টারের আসল রিডিং *';

  @override
  String get enterValidPositiveNumber => 'সঠিক ধনাত্মক সংখ্যা দিন';

  @override
  String kmAddedOfflineRiding(Object delta) {
    return '+$delta কিমি যোগ হয়েছে (অফলাইন রাইড ধরা হয়েছে)';
  }

  @override
  String kmReductionCalibratingBaseline(Object delta) {
    return '$delta কিমি কমেছে (বেসলাইন ঠিক করা হচ্ছে)';
  }

  @override
  String get confirmSyncOdometer => 'নিশ্চিত করে ওডোমিটার সিঙ্ক করুন';

  @override
  String get resetSelectedItems => 'বেছে নেওয়া আইটেম রিসেট করবেন?';

  @override
  String thisLogsAsServiced(Object label) {
    return 'এতে \"$label\" আজ বাইকের বর্তমান ওডোমিটারে সার্ভিস করা হিসেবে লগ হবে এবং বাকি হওয়ার তারিখ রিসেট হবে। আগের ইতিহাস থেকে যাবে।';
  }

  @override
  String thisLogsItemsAs(Object selectedCount) {
    return 'এতে $selectedCountটি আইটেম আজ বাইকের বর্তমান ওডোমিটারে সার্ভিস করা হিসেবে লগ হবে এবং তাদের বাকি হওয়ার তারিখ রিসেট হবে। আগের ইতিহাস থেকে যাবে।';
  }

  @override
  String get reset => 'রিসেট';

  @override
  String get n1ItemResetServiced =>
      '1টি আইটেম আজ সার্ভিস করা হিসেবে রিসেট হয়েছে।';

  @override
  String itemsResetServicedToday(Object count) {
    return '$countটি আইটেম আজ সার্ভিস করা হিসেবে রিসেট হয়েছে।';
  }

  @override
  String get resetServiceLogTitle => 'সার্ভিস লগ রিসেট';

  @override
  String tickWhatJustServiced(Object displayName) {
    return '$displayName-এ যা এইমাত্র সার্ভিস করালেন তা টিক দিন';
  }

  @override
  String get selectedItemsLoggedAs =>
      'বেছে নেওয়া আইটেম আজ বর্তমান ওডোমিটারে সার্ভিস করা হিসেবে লগ হবে এবং বাকি হওয়ার তারিখ রিসেট হবে। কিছুই মুছবে না।';

  @override
  String get noTrackedChecksYet =>
      'এখনো কোনো চেক ট্র্যাক করা হচ্ছে না। আগে \"কাস্টমাইজ\"-এ গিয়ে কিছু সেট করুন।';

  @override
  String selectedOfTotal(Object selectedCount, Object remindersCount) {
    return '$remindersCountটির মধ্যে $selectedCountটি নির্বাচিত';
  }

  @override
  String get selectItemsReset => 'রিসেট করতে আইটেম বেছে নিন';

  @override
  String lastDoneKmAgo(Object kmSinceService) {
    return 'সর্বশেষ $kmSinceService কিমি আগে করা হয়েছে';
  }

  @override
  String get cropBikePhoto => 'বাইকের ছবি ক্রপ করুন';

  @override
  String get bikeAdded => 'বাইক যোগ হয়েছে।';

  @override
  String get setServiceIntervals => 'সার্ভিস ইন্টারভাল ঠিক করুন';

  @override
  String get editBike => 'বাইক সম্পাদনা';

  @override
  String get addPhoto => 'ছবি যোগ করুন';

  @override
  String get crop => 'ক্রপ';

  @override
  String get replace => 'বদলান';

  @override
  String get odometerReadingKm => 'ওডোমিটার রিডিং (কিমি)';

  @override
  String get bikeColor => 'বাইকের রং';

  @override
  String get saveChanges => 'পরিবর্তন সেভ করুন';

  @override
  String get bikeNotFound => 'বাইক পাওয়া যায়নি';

  @override
  String archived(Object displayName) {
    return '$displayName (আর্কাইভ করা)';
  }

  @override
  String get discussThisBike => 'এই বাইক নিয়ে আলোচনা';

  @override
  String get unarchiveBike => 'বাইক আর্কাইভ থেকে ফিরিয়ে আনুন';

  @override
  String get archiveDeleteBike => 'বাইক আর্কাইভ বা মুছুন';

  @override
  String get totalDistance => 'মোট দূরত্ব';

  @override
  String get totalRides => 'মোট রাইড';

  @override
  String get odometer => 'ওডোমিটার';

  @override
  String get engine => 'ইঞ্জিন';

  @override
  String get rideHistory => 'রাইডের ইতিহাস';

  @override
  String get noRidesYetThis => 'এই বাইকের এখনো কোনো রাইড নেই';

  @override
  String removeBikeQuestion(Object displayName) {
    return '$displayName সরাবেন?';
  }

  @override
  String get archivingHidesThisBike =>
      'আর্কাইভ করলে বাইকটি আপনার গ্যারেজ ও বাইক বাছাইয়ের তালিকা থেকে লুকিয়ে যাবে। এর রাইডগুলো আপনার ইতিহাস ও পরিসংখ্যানে থাকবে, আর যেকোনো সময় আর্কাইভ থেকে ফিরিয়ে আনতে পারবেন।';

  @override
  String get deleteBikeAllIts => 'বাইক ও এর সব রাইড মুছুন';

  @override
  String get archiveBikeKeepRides => 'বাইক আর্কাইভ করুন (রাইড থাকবে)';

  @override
  String couldNotArchiveThis(Object e) {
    return 'বাইকটি আর্কাইভ করা যায়নি: $e';
  }

  @override
  String couldNotDeleteThis(Object e) {
    return 'বাইকটি মুছে ফেলা যায়নি: $e';
  }

  @override
  String get bikeBackGarage => 'বাইকটি আপনার গ্যারেজে ফিরে এসেছে';

  @override
  String couldNotUnarchiveThis(Object e) {
    return 'বাইকটি আর্কাইভ থেকে ফেরানো যায়নি: $e';
  }

  @override
  String get deleteBikeQuestion => 'বাইক ও এর সব রাইড মুছবেন?';

  @override
  String get usingDefaultServiceIntervals =>
      'ডিফল্ট সার্ভিস ইন্টারভাল ব্যবহার হচ্ছে';

  @override
  String get serviceMaintenance => 'সার্ভিস ও মেইনটেন্যান্স';

  @override
  String nextSummary(Object summary) {
    return 'পরবর্তী: $summary';
  }

  @override
  String get intervals => 'ইন্টারভাল';

  @override
  String get viewAll => 'সব দেখুন';

  @override
  String get yourBikesTitle => 'আপনার বাইকগুলো';

  @override
  String get viewProfile => 'প্রোফাইল দেখুন';

  @override
  String get myPlaces => 'আমার জায়গা';

  @override
  String get noBikesYet => 'এখনো কোনো বাইক নেই';

  @override
  String get addFirstBikeGet => 'শুরু করতে আপনার প্রথম বাইকটি যোগ করুন';

  @override
  String get setActive => 'সক্রিয় করুন';

  @override
  String get totalLower => 'মোট';

  @override
  String get ridesLower => 'রাইড';

  @override
  String get lastRide => 'সর্বশেষ রাইড';

  @override
  String archivedBikes(Object bikesCount) {
    return 'আর্কাইভ করা বাইক ($bikesCount)';
  }

  @override
  String ridesAndDistance(Object rideCount, Object totalDistanceM) {
    return '$rideCountটি রাইড · $totalDistanceM';
  }

  @override
  String get unarchive => 'আর্কাইভ থেকে ফেরান';

  @override
  String get myFollowers => 'আমার ফলোয়াররা';

  @override
  String get onlyMe => 'শুধু আমি';

  @override
  String get blockedUsers => 'ব্লক করা ইউজার';

  @override
  String get noBlockedUsers => 'কোনো ব্লক করা ইউজার নেই';

  @override
  String get errorLoadingUser => 'ইউজার লোড করতে ত্রুটি';

  @override
  String get unknownUser => 'অজানা ইউজার';

  @override
  String get unblock => 'আনব্লক';

  @override
  String couldNotSaveProfile(Object e) {
    return 'প্রোফাইল সেভ করা যায়নি: $e';
  }

  @override
  String get editProfile => 'প্রোফাইল সম্পাদনা';

  @override
  String get displayName => 'প্রদর্শিত নাম';

  @override
  String get nickname => 'ডাকনাম';

  @override
  String get shownCardsFeed => 'কার্ড ও ফিডে দেখানো হয়';

  @override
  String get usernameField => 'ইউজারনেম';

  @override
  String get n320LettersNumbers => '3-20টি অক্ষর, সংখ্যা বা আন্ডারস্কোর';

  @override
  String get bio => 'বায়ো';

  @override
  String get whoCanSeeProfile => 'কে আমার প্রোফাইল দেখতে পারবে';

  @override
  String get everyone => 'সবাই';

  @override
  String get mutuals => 'পারস্পরিক ফলোয়ার';

  @override
  String get whoCanSeeBikes => 'কে আমার বাইক দেখতে পারবে';

  @override
  String get garageProfileSeparateFrom =>
      'আপনার প্রোফাইলে থাকা গ্যারেজ। প্রোফাইল কে দেখতে পাবে তার থেকে আলাদা।';

  @override
  String get tellRidersAboutYourself => 'রাইডারদের নিজের সম্পর্কে বলুন';

  @override
  String get goodBioGetsMore => 'ভালো বায়ো আপনার ফলোয়ার বাড়ায়।';

  @override
  String get eGFzS =>
      'যেমন: \"ঢাকার FZ-S রাইডার। সাপ্তাহিক ট্যুরার। কফি আর বাঁক।\"';

  @override
  String get saveBio => 'বায়ো সেভ করুন';

  @override
  String get privacySafety => 'গোপনীয়তা ও নিরাপত্তা';

  @override
  String get manageAccountsHaveBlocked =>
      'আপনার ব্লক করা অ্যাকাউন্টগুলো পরিচালনা করুন';

  @override
  String get seeDemoFeatureTour => 'ডেমো ও ফিচার ট্যুর দেখুন';

  @override
  String get replayInteractiveFeatureGuides =>
      'ইন্টারঅ্যাক্টিভ ফিচার গাইড ও নিরাপত্তা ওয়াকথ্রু আবার দেখুন';

  @override
  String get sendBugReport => 'বাগ রিপোর্ট পাঠান';

  @override
  String get somethingBrokenLetTeam => 'কিছু কাজ করছে না? টিমকে জানান';

  @override
  String get deleteAccount => 'অ্যাকাউন্ট মুছুন';

  @override
  String get deleteAccountQuestion => 'অ্যাকাউন্ট মুছবেন?';

  @override
  String get thisActionIrreversibleAll =>
      'এই কাজটি ফেরানো যাবে না। আপনার সব রেকর্ড করা রাইড, বাইক প্রোফাইল, পরিসংখ্যান ও ব্যক্তিগত তথ্য চিরতরে মুছে যাবে।';

  @override
  String get deletePermanently => 'চিরতরে মুছুন';

  @override
  String get deletingAccount => 'অ্যাকাউন্ট মুছে ফেলা হচ্ছে...';

  @override
  String errorDeletingAccount(Object e) {
    return 'অ্যাকাউন্ট মুছতে ত্রুটি: $e';
  }

  @override
  String get syncIssues => 'সিঙ্ক সমস্যা';

  @override
  String get n1UpdateCouldntBe => '1টি আপডেট পাঠানো যায়নি';

  @override
  String updatesCouldntBeSent(Object count) {
    return '$countটি আপডেট পাঠানো যায়নি';
  }

  @override
  String get rideShare => 'রাইড শেয়ার';

  @override
  String get endingLiveShare => 'লাইভ শেয়ার বন্ধ করা';

  @override
  String get maintenanceLog => 'মেইনটেন্যান্স লগ';

  @override
  String get cloudUpdate => 'ক্লাউড আপডেট';

  @override
  String get everythingSynced => 'সবকিছু সিঙ্ক হয়েছে';

  @override
  String get synced => 'সিঙ্ক হয়েছে';

  @override
  String get couldntSyncYetWell =>
      'এখনো সিঙ্ক করা যায়নি। আমরা ব্যাকগ্রাউন্ডে চেষ্টা চালিয়ে যাব।';

  @override
  String get discardThisUpdate => 'এই আপডেট বাদ দেবেন?';

  @override
  String get itWontBeSent => 'এটি পাঠানো হবে না। এটি ফেরানো যাবে না।';

  @override
  String get signViewProfile => 'প্রোফাইল দেখতে সাইন ইন করুন';

  @override
  String get userBlocked => 'ইউজার ব্লক করা হয়েছে';

  @override
  String get reportUser => 'ইউজার রিপোর্ট করুন';

  @override
  String get blockUser => 'ইউজার ব্লক করুন';

  @override
  String couldntBlockRider(String error) {
    return 'এই রাইডারকে ব্লক করা যায়নি: $error';
  }

  @override
  String get publicLiveLinkTitle => 'পাবলিক লিংক (/r/@handle)';

  @override
  String get publicLiveLinkDesc =>
      'লাইভ রাইড শেয়ার করার সময় আপনার @ইউজারনেম জানা যে কেউ /r/@username লিংকে রাইডটি দেখতে পারবে — অ্যাপ বা সাইন-ইন লাগবে না। শুরুতে বন্ধ থাকে। আপনার ব্যক্তিগত লাইভ লিংক দুই ক্ষেত্রেই কাজ করবে।';

  @override
  String get audienceAnyFollower => 'আপনার যেকোনো ফলোয়ার';

  @override
  String get tapEditFinishSetting =>
      'প্রোফাইল সেটআপ শেষ করতে সম্পাদনায় ট্যাপ করুন';

  @override
  String get riderNotFound => 'রাইডার পাওয়া যায়নি';

  @override
  String ridingWithUsSince(Object createdAt) {
    return '$createdAt থেকে আমাদের সাথে রাইড করছেন';
  }

  @override
  String get followersLabel => 'ফলোয়ার';

  @override
  String get followingLabel => 'ফলো করছেন';

  @override
  String get message => 'মেসেজ';

  @override
  String get totalDistanceLower => 'মোট দূরত্ব';

  @override
  String get ridesLogged => 'রাইড লগ হয়েছে';

  @override
  String get badges => 'ব্যাজ';

  @override
  String get noBadgesEarnedYet => 'এখনো কোনো ব্যাজ অর্জন করেননি';

  @override
  String get myGarageLower => 'আমার গ্যারেজ';

  @override
  String get garage => 'গ্যারেজ';

  @override
  String get whoCanSeeBikesChangeUnderEdit =>
      'কে আমার বাইক দেখতে পারবে — এটি সম্পাদনা থেকে বদলান';

  @override
  String get thisProfilePrivate => 'এই প্রোফাইলটি ব্যক্তিগত';

  @override
  String get youreOffline => 'আপনি অফলাইনে আছেন';

  @override
  String get couldntLoadProfile => 'প্রোফাইল লোড করা যায়নি';

  @override
  String resetItemsButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি আইটেম রিসেট করুন',
      one: '1টি আইটেম রিসেট করুন',
    );
    return '$_temp0';
  }

  @override
  String deleteBikeConfirmBody(int rides, String expected) {
    String _temp0 = intl.Intl.pluralLogic(
      rides,
      locale: localeName,
      other: '$ridesটি রাইড',
      one: '1টি রাইড',
    );
    return 'এটি $_temp0, সেগুলোর রুট এবং এই বাইকের মেইনটেন্যান্স লগ এই ফোন ও ক্লাউড — দুই জায়গা থেকেই চিরতরে মুছে ফেলবে। নিশ্চিত করতে \"$expected\" টাইপ করুন।';
  }

  @override
  String get svcTypeOilChange => 'অয়েল চেঞ্জ';

  @override
  String get svcTypeAirFilter => 'এয়ার ফিল্টার';

  @override
  String get svcTypeChain => 'চেইন লুব';

  @override
  String get svcTypeTire => 'টায়ার চেক';

  @override
  String get svcTypeRadiatorCoolant => 'রেডিয়েটর / কুল্যান্ট';

  @override
  String get svcTypeFrontDiscPads => 'সামনের ডিস্ক প্যাড';

  @override
  String get svcTypeRearDrumPads => 'পেছনের ড্রাম প্যাড';

  @override
  String get svcTypeBrakeFluid => 'ব্রেক ফ্লুইড';

  @override
  String get svcTypeSparkPlug => 'স্পার্ক প্লাগ';

  @override
  String get svcTypeBattery => 'ব্যাটারি';

  @override
  String get svcTypeValveClearance => 'ভালভ ক্লিয়ারেন্স';

  @override
  String get svcTypeClutchCable => 'ক্লাচ ক্যাবল';

  @override
  String get svcTypeSuspension => 'সাসপেনশন';

  @override
  String get svcTypeOilFilter => 'অয়েল ফিল্টার';

  @override
  String get svcTypeChainTension => 'চেইন স্ল্যাক ও টেনশন';

  @override
  String get svcTypeBrakeRotors => 'ব্রেক রোটর / ডিস্ক';

  @override
  String get svcTypeForkSeals => 'ফর্ক অয়েল ও সিল';

  @override
  String get svcTypeWheelBearings => 'হুইল বিয়ারিং';

  @override
  String get svcTypeDriveBelt => 'ড্রাইভ বেল্ট';

  @override
  String get svcTypeThrottleCables => 'থ্রটল ও ক্যাবল';

  @override
  String get svcTypeFuel => 'জ্বালানি';

  @override
  String get svcTypeCustom => 'কাস্টম';

  @override
  String get svcDescOilChange => 'ইঞ্জিন অয়েল ফেলে নতুন লুব্রিক্যান্ট ভরুন।';

  @override
  String get svcDescOilFilter =>
      'ময়লা জমা ঠেকাতে অয়েল ফিল্টার এলিমেন্ট বদলান।';

  @override
  String get svcDescAirFilter =>
      'ভালো বাতাস চলাচলের জন্য ইনটেক ফিল্টার পরিষ্কার করুন বা বদলান।';

  @override
  String get svcDescChain =>
      'রাস্তার ময়লা পরিষ্কার করে ড্রাইভ চেইনে লুব লাগান।';

  @override
  String get svcDescChainTension =>
      'ড্রাইভ চেইনের স্ল্যাক দেখুন ও রিয়ার এক্সেল ঠিকমতো বসান।';

  @override
  String get svcDescTire =>
      'টায়ারের প্রেশার, ট্রেড ক্ষয় ও ফাটল পরীক্ষা করুন।';

  @override
  String get svcDescRadiatorCoolant =>
      'রেডিয়েটরের কুল্যান্ট ফ্লাশ করে নতুন করে ভরুন।';

  @override
  String get svcDescFrontDiscPads =>
      'সামনের ব্রেক প্যাডের ফ্রিকশন ম্যাটেরিয়ালের পুরুত্ব দেখুন।';

  @override
  String get svcDescRearDrumPads =>
      'পেছনের ব্রেক প্যাড বা ড্রাম ব্রেক শু পরীক্ষা করুন।';

  @override
  String get svcDescBrakeFluid =>
      'হাইড্রোলিক DOT ব্রেক ফ্লুইড ব্লিড করে নতুন ভরুন।';

  @override
  String get svcDescSparkPlug =>
      'ইলেক্ট্রোডের গ্যাপ দেখুন বা স্পার্ক প্লাগ বদলান।';

  @override
  String get svcDescBattery =>
      'টার্মিনালের ভোল্টেজ, সংযোগ ও চার্জের অবস্থা পরীক্ষা করুন।';

  @override
  String get svcDescValveClearance =>
      'ইনটেক / এক্সহস্ট ভালভের ক্লিয়ারেন্স মেপে ঠিক করুন।';

  @override
  String get svcDescClutchCable =>
      'লিভারের ফ্রি-প্লে দেখুন ও ক্লাচ ক্যাবলে লুব দিন।';

  @override
  String get svcDescThrottleCables =>
      'থ্রটলের প্লে ও স্ন্যাপ-ব্যাক দেখুন এবং ক্যাবলে লুব দিন।';

  @override
  String get svcDescSuspension =>
      'পেছনের শক ড্যাম্পিং ও লিঙ্কেজ পিভট বুশিং পরীক্ষা করুন।';

  @override
  String get svcDescForkSeals =>
      'সামনের ফর্ক সিলে তেল চুঁইয়ে পড়ছে কিনা দেখুন ও ফর্ক অয়েল বদলান।';

  @override
  String get svcDescBrakeRotors =>
      'ব্রেক ডিস্কের পুরুত্ব মাপুন ও বেঁকে গেছে কিনা দেখুন।';

  @override
  String get svcDescWheelBearings =>
      'সামনের ও পেছনের হুইল বিয়ারিংয়ে প্লে বা খসখসে ভাব দেখুন।';

  @override
  String get svcDescDriveBelt =>
      'বেল্টের ডিফ্লেকশন, দাঁতের অবস্থা ও টেনশন দেখুন।';

  @override
  String get svcDescFuel =>
      'জ্বালানি ভরা, ট্যাংকের রেঞ্জ ও জ্বালানির ধরন ট্র্যাক করুন।';

  @override
  String get svcDescCustom => 'রাইডারের নিজের ঠিক করা মেইনটেন্যান্স চেক।';

  @override
  String get maintCatEngine => 'ইঞ্জিন ও ফ্লুইড';

  @override
  String get maintCatDrivetrain => 'ড্রাইভ ও কন্ট্রোল';

  @override
  String get maintCatBraking => 'ব্রেকিং সিস্টেম';

  @override
  String get maintCatChassisElectrical => 'চ্যাসিস ও ইলেকট্রিক্যাল';

  @override
  String serviceOverdueBy(String item, String km) {
    return '$item · $km কিমি ওভারডিউ';
  }

  @override
  String serviceDueIn(String item, String km) {
    return '$item · আরও $km কিমি পরে বাকি';
  }

  @override
  String get noReviewsYet => 'এখনো কোনো রিভিউ নেই';

  @override
  String get pickLocationMapFirst => 'আগে ম্যাপে লোকেশন বেছে নিন।';

  @override
  String get takeAPhoto => 'ছবি তুলুন';

  @override
  String get chooseFromGallery => 'গ্যালারি থেকে বেছে নিন';

  @override
  String get couldNotOpenCamera => 'ক্যামেরা বা গ্যালারি খোলা যায়নি।';

  @override
  String get couldntLookThatSpot =>
      'জায়গাটি খুঁজে পাওয়া যায়নি — নিজেই বর্ণনা লিখে দিন।';

  @override
  String get photoDidntUploadSaving =>
      'ছবি আপলোড হয়নি — ছবি ছাড়াই জায়গাটি সেভ করা হচ্ছে।';

  @override
  String couldNotAddPlace(Object e) {
    return 'জায়গা যোগ করা যায়নি: $e';
  }

  @override
  String get addPhotoOptional => 'ছবি যোগ করুন (ঐচ্ছিক)';

  @override
  String get shopfrontPictureMakesThis =>
      'দোকানের সামনের ছবি থাকলে জায়গাটি চিনতে সুবিধা হয়';

  @override
  String get couldntLoadThatPhoto => 'ছবিটি লোড করা যায়নি';

  @override
  String get replacePhoto => 'ছবি বদলান';

  @override
  String get removePhoto => 'ছবি সরান';

  @override
  String get addPlace => 'জায়গা যোগ করুন';

  @override
  String get location => 'লোকেশন';

  @override
  String get category => 'ক্যাটাগরি';

  @override
  String get nameStar => 'নাম *';

  @override
  String get eGRahmanMotors => 'যেমন: রহমান মোটরস';

  @override
  String get addressOptional => 'ঠিকানা (ঐচ্ছিক)';

  @override
  String get eGBesideOmuk => 'যেমন: মিরপুর 10-এ অমুক স্কুলের পাশে';

  @override
  String get writeItWayYoud =>
      'বন্ধুকে যেভাবে বলতেন সেভাবে লিখুন — আনুষ্ঠানিক ঠিকানা নয়, চেনা জায়গার কথা। \"অমুক স্কুলের পাশে\" বা \"মিরপুর 10 চত্বরের ঠিক পরে\" লিখলে অনেক বেশি কাজে লাগে।';

  @override
  String get lookingUp => 'খোঁজা হচ্ছে…';

  @override
  String get usePinsArea => 'পিনের এলাকা ব্যবহার করুন';

  @override
  String get phoneOptional => 'ফোন (ঐচ্ছিক)';

  @override
  String get hoursOptional => 'সময় (ঐচ্ছিক)';

  @override
  String get eG9am9pm => 'যেমন: সকাল 9টা – রাত 9টা, অথবা 24/7';

  @override
  String get haventAddedAnyPlaces => 'আপনি এখনো কোনো জায়গা যোগ করেননি';

  @override
  String verified(Object displayName) {
    return '$displayName · যাচাইকৃত';
  }

  @override
  String get youveAlreadyReviewedThis => 'আপনি এই জায়গার রিভিউ আগেই দিয়েছেন।';

  @override
  String couldNotSubmitReview(Object e) {
    return 'রিভিউ জমা দেওয়া যায়নি: $e';
  }

  @override
  String get place => 'জায়গা';

  @override
  String get placeNotFound => 'জায়গা পাওয়া যায়নি';

  @override
  String get addReview => 'আপনার রিভিউ যোগ করুন';

  @override
  String get rateThisPlace => 'এই জায়গার রেটিং দিন';

  @override
  String get shareExperience => 'আপনার অভিজ্ঞতা জানান...';

  @override
  String get submitReview => 'রিভিউ জমা দিন';

  @override
  String get reviews => 'রিভিউ';

  @override
  String get noReviewsYetBe => 'এখনো কোনো রিভিউ নেই — প্রথমজন আপনিই হোন!';

  @override
  String get officialPoint => 'অফিসিয়াল পয়েন্ট';

  @override
  String get n0NotGoogle => '★ 0 (Google-এ নেই)';

  @override
  String get n00Reviews => '★ 0 (0টি রিভিউ)';

  @override
  String get couldntOpenMapsApp => 'দিকনির্দেশের জন্য ম্যাপ অ্যাপ খোলা যায়নি';

  @override
  String get couldntOpenDialler => 'ডায়ালার খোলা যায়নি';

  @override
  String get call => 'কল করুন';

  @override
  String get youLabel => 'আপনি';

  @override
  String get recordThisRideThrottleiq =>
      'এই রাইড কি ThrottleIQ-তে রেকর্ড করবেন?';

  @override
  String get mapsAppGivesDirections =>
      'দিকনির্দেশ দেবে আপনার ম্যাপ অ্যাপ। একই সময়ে ThrottleIQ ব্যাকগ্রাউন্ডে ট্রিপটি লগ করতে পারে।';

  @override
  String get recordGo => 'রেকর্ড করে রওনা দিন';

  @override
  String get justDirections => 'শুধু দিকনির্দেশ';

  @override
  String get dontAskAgain => 'আর জিজ্ঞেস করবেন না';

  @override
  String get noNewPlacesFound => 'কাছাকাছি নতুন কোনো জায়গা পাওয়া যায়নি';

  @override
  String couldNotImportNearby(Object e) {
    return 'কাছের জায়গা ইম্পোর্ট করা যায়নি: $e';
  }

  @override
  String get importNearbyPlacesFrom =>
      'OpenStreetMap থেকে কাছের জায়গা ইম্পোর্ট করুন';

  @override
  String get allFilter => 'সব';

  @override
  String get browseRoutes => 'রুট দেখুন →';

  @override
  String get openSettings => 'সেটিংস খুলুন';

  @override
  String get noPlacesNearbyYet => 'কাছে এখনো কোনো জায়গা নেই';

  @override
  String get addGarageFuelPump =>
      'অন্য রাইডারদের সাহায্য করতে গ্যারেজ, ফুয়েল পাম্প, যন্ত্রাংশের দোকান বা বাইকার ক্যাফে যোগ করুন।';

  @override
  String get addPlaceLower => 'জায়গা যোগ করুন';

  @override
  String get placesHubTabPlaces => 'জায়গা';

  @override
  String get placesHubTabRoutes => 'রুট';

  @override
  String get placesHubTabSaved => 'সংরক্ষিত';

  @override
  String get placesSearchHint => 'পাম্প, গ্যারেজ, বাইকার ক্যাফে খুঁজুন…';

  @override
  String get placesClearSearch => 'খোঁজা মুছুন';

  @override
  String get placesFiltersTooltip => 'ফিল্টার';

  @override
  String get placesMapView => 'ম্যাপ';

  @override
  String get placesListView => 'তালিকা';

  @override
  String get placesLocateMe => 'আমার অবস্থানে যান';

  @override
  String get placesRadiusLabel => 'খোঁজার পরিধি';

  @override
  String placesRadiusKm(String km) {
    return '$km কিমি';
  }

  @override
  String get placesSortLabel => 'সাজান';

  @override
  String get placesSortDistance => 'সবচেয়ে কাছে';

  @override
  String get placesSortRating => 'সেরা রেটিং';

  @override
  String get placesVerifiedOnly => 'শুধু যাচাই করা জায়গা';

  @override
  String get placesVerifiedOnlyHint => 'ThrottleIQ টিম যাচাই করেছে';

  @override
  String get placesFeaturesLabel => 'সুবিধা';

  @override
  String get placesFiltersReset => 'রিসেট';

  @override
  String get placesNoMatches => 'মিলে যায় এমন কোনো জায়গা নেই';

  @override
  String get placesNoMatchesHint =>
      'আরও বড় পরিধি, অন্য ক্যাটাগরি বা কম ফিল্টার দিয়ে চেষ্টা করুন।';

  @override
  String get placesClearFilters => 'ফিল্টার মুছুন';

  @override
  String placesWidenRadius(String km) {
    return '$km কিমি জুড়ে খুঁজুন';
  }

  @override
  String get placeTagOpen24h => '24/7 খোলা';

  @override
  String get placeTagOctane95 => 'অকটেন 95';

  @override
  String get placeTagDigitalPayment => 'ডিজিটাল পেমেন্ট';

  @override
  String get placeTagEfiDiagnostics => 'ইএফআই ডায়াগনস্টিক';

  @override
  String get placeTagPunctureRepair => 'পাংচার সারাই';

  @override
  String get placeTagPaddockStand => 'প্যাডক স্ট্যান্ড';

  @override
  String get placeTagGenuineParts => 'আসল পার্টস';

  @override
  String get placeTagBikeParking => 'বাইক পার্কিং';

  @override
  String get placeTagRestrooms => 'শৌচাগার';

  @override
  String placeApproxMinutes(int minutes) {
    return '~$minutes মিনিট';
  }

  @override
  String get placeVerifiedBadge => 'যাচাই করা';

  @override
  String get placeRiderApproved => 'রাইডারদের পছন্দ';

  @override
  String get placeRiderApprovedHint =>
      'অন্তত 5 জন ThrottleIQ রাইডার 4.5★ বা বেশি দিয়েছেন';

  @override
  String placeGoogleRatingBadge(String rating, int count) {
    return '★ $rating ($count গুগল)';
  }

  @override
  String placeRiderRatingBadge(String rating, int count) {
    return '★ $rating ($count জন রাইডার)';
  }

  @override
  String get placeSave => 'সংরক্ষণ';

  @override
  String get placeSavedLabel => 'সংরক্ষিত';

  @override
  String get placeSavedSnack => 'সংরক্ষিত — অফলাইনেও সংরক্ষিত ট্যাবে পাবেন';

  @override
  String get placeUnsavedSnack => 'সংরক্ষিত জায়গা থেকে সরানো হয়েছে';

  @override
  String get placeSaveFailed => 'সংরক্ষিত জায়গা আপডেট করা যায়নি';

  @override
  String get radarTitle => 'হাইওয়ে রাডার';

  @override
  String radarCameras(int count) {
    return '$countটি স্পিড ক্যামেরা';
  }

  @override
  String radarPolice(int count) {
    return '$countটি পুলিশ চেকপোস্ট';
  }

  @override
  String radarWithin(String km) {
    return '$km কিমির মধ্যে';
  }

  @override
  String radarNearest(String distance) {
    return 'সবচেয়ে কাছেরটি $distance দূরে';
  }

  @override
  String get radarShowOnMap => 'ম্যাপে দেখুন';

  @override
  String get radarHideOnMap => 'ম্যাপ থেকে লুকান';

  @override
  String get radarDismiss => 'রাডার বন্ধ করুন';

  @override
  String get radarListTitle => 'আপনার কাছের সতর্কতার জায়গা';

  @override
  String get placesScanOsmTitle => 'এখানে এখনো কিছু ম্যাপ করা নেই';

  @override
  String get placesScanOsmBody =>
      'ThrottleIQ ফ্রি কমিউনিটি ম্যাপ OpenStreetMap থেকে এই এলাকার ফুয়েল পাম্প, গ্যারেজ ও পার্টসের দোকান আনতে পারে। আপনি ট্যাপ করলেই শুধু চলে, আর কোনো জায়গা দুবার যোগ করে না।';

  @override
  String get placesScanOsm => 'OpenStreetMap স্ক্যান করুন';

  @override
  String get placesScanning => 'স্ক্যান হচ্ছে…';

  @override
  String get placesOsmDialogTitle => 'OpenStreetMap থেকে ইম্পোর্ট করবেন?';

  @override
  String placesOsmDialogBody(String km) {
    return '$km কিমির মধ্যে যেসব ফুয়েল পাম্প, গ্যারেজ ও পার্টসের দোকান OpenStreetMap-এ আছে কিন্তু ThrottleIQ-তে এখনো নেই, সেগুলো যোগ করে। আগে থেকে থাকা জায়গা আবার যোগ হয় না।';
  }

  @override
  String get placesOsmImportAction => 'ইম্পোর্ট';

  @override
  String get placesMoreActions => 'আরও';

  @override
  String get placesAddedByMe => 'আমার যোগ করা জায়গা';

  @override
  String get placesLocationDeniedTitle =>
      'ThrottleIQ আপনার অবস্থান দেখতে পাচ্ছে না';

  @override
  String get placesAllowLocation => 'অবস্থানের অনুমতি দিন';

  @override
  String get placesGpsOffTitle => 'জিপিএস বন্ধ';

  @override
  String get placesOfflineTitle => 'আপনি অফলাইনে আছেন';

  @override
  String get placesOfflineBody =>
      'কাছের জায়গা দেখতে ইন্টারনেট লাগে। সংরক্ষিত জায়গাগুলো অফলাইনেও কাজ করে।';

  @override
  String get placesOpenSaved => 'সংরক্ষিত জায়গা খুলুন';

  @override
  String get savedPlacesEmptyTitle => 'এখনো কোনো জায়গা সংরক্ষণ করা হয়নি';

  @override
  String get savedPlacesEmptyBody =>
      'যেকোনো জায়গার বুকমার্কে ট্যাপ করে এখানে রাখুন। নেটওয়ার্ক না থাকলেও সংরক্ষিত জায়গা কাজ করে।';

  @override
  String get savedPlacesContributedBody =>
      'অন্য রাইডারদের জন্য আপনার যোগ করা জায়গাগুলো দেখুন ও ম্যানেজ করুন।';

  @override
  String get addPlaceFeaturesLabel => 'সুবিধা (ঐচ্ছিক)';

  @override
  String get addPlaceFeaturesHint => 'পরের রাইডার কী জানলে খুশি হবেন?';

  @override
  String placesResultCount(int count) {
    return '$countটি জায়গা';
  }

  @override
  String couldNotUpdateVisibility(Object e) {
    return 'দৃশ্যমানতা বদলানো যায়নি: $e';
  }

  @override
  String get deleteRouteQuestion => 'রুট মুছবেন?';

  @override
  String get thisRemovesSavedRoute =>
      'এতে সেভ করা রুটটি মুছে যাবে। যে রাইড থেকে এটি এসেছে সেটি অপরিবর্তিত থাকবে।';

  @override
  String get deleteRouteTitle => 'রুট মুছুন';

  @override
  String get routeNotFound => 'রুট পাওয়া যায়নি';

  @override
  String get turns => 'বাঁক';

  @override
  String get ridden => 'চালানো হয়েছে';

  @override
  String get privateLabel => 'ব্যক্তিগত';

  @override
  String get anyRiderCanFind => 'যেকোনো রাইডার এই রুট খুঁজে নিয়ে চালাতে পারবে';

  @override
  String get onlyCanSeeThis => 'শুধু আপনি এই রুটটি দেখতে পারবেন';

  @override
  String get startNavigation => 'নেভিগেশন শুরু করুন';

  @override
  String get turnByTurn => 'বাঁকে বাঁকে নির্দেশনা';

  @override
  String get derivedFromRecordedTrack =>
      'রেকর্ড করা ট্র্যাক থেকে তৈরি — দূরত্ব রুট ধরে মাপা।';

  @override
  String get sharedByAnotherRider => 'অন্য রাইডারের শেয়ার করা';

  @override
  String sharedBy(Object value) {
    return '$value-এর শেয়ার করা';
  }

  @override
  String get canRideItBut =>
      'আপনি এটি চালাতে পারবেন, কিন্তু শুধু মালিকই এটি বদলাতে বা মুছতে পারবেন।';

  @override
  String get locationPermissionOffSo =>
      'লোকেশন অনুমতি বন্ধ, তাই বাঁক ট্র্যাক করা যাচ্ছে না। নেভিগেট করতে সেটিংসে গিয়ে চালু করুন।';

  @override
  String get locationServicesOffTurn =>
      'লোকেশন সার্ভিস বন্ধ আছে। নেভিগেট করতে চালু করুন।';

  @override
  String get thisRouteHasNo => 'এই রুটে অনুসরণ করার মতো কোনো ট্র্যাক নেই।';

  @override
  String offRouteFromLine(Object distanceM) {
    return 'রুটের বাইরে — লাইন থেকে $distanceM দূরে';
  }

  @override
  String get remaining => 'বাকি';

  @override
  String get eta => 'পৌঁছাবে (ETA)';

  @override
  String get end => 'শেষ';

  @override
  String get etaUnderAMinute => '<1 মিনিট';

  @override
  String etaMinutes(Object minutes) {
    return '$minutes মিনিট';
  }

  @override
  String etaHoursMinutes(Object hours, Object minutes) {
    return '$hoursঘ $minutesমি';
  }

  @override
  String navInDistance(Object distance) {
    return '$distance পরে';
  }

  @override
  String get navArrivedStillRecording => 'পৌঁছে গেছেন — রেকর্ডিং চলছে';

  @override
  String get navGuidanceStoppedStillRecording =>
      'গাইডেন্স বন্ধ। আপনার রাইড এখনও রেকর্ড হচ্ছে।';

  @override
  String get navStopGuidance => 'গাইডেন্স বন্ধ করুন';

  @override
  String navRoutePreflightSummary(Object distance, Object turns) {
    return '$distance · $turnsটি টার্ন';
  }

  @override
  String get navRecordsRideExplainer =>
      'এই রুট অনুসরণ করলে রেকর্ড বোতামের মতোই একটি রাইড রেকর্ড হবে।';

  @override
  String get navAttachExplainer =>
      'আপনি যে রাইডটি রেকর্ড করছেন তাতেই গাইডেন্স যোগ হবে।';

  @override
  String get navStartRideAndGuide => 'রাইড শুরু করে গাইড করুন';

  @override
  String get navGuideOnThisRide => 'এই রাইডে গাইড করুন';

  @override
  String followedRoutePill(Object name) {
    return '$name অনুসরণ করা হয়েছে';
  }

  @override
  String get routes => 'রুট';

  @override
  String get myRoutes => 'আমার রুট';

  @override
  String get discover => 'আবিষ্কার করুন';

  @override
  String get noSavedRoutesYet => 'এখনো কোনো সেভ করা রুট নেই';

  @override
  String get noPublicRoutesYet => 'এখনো কোনো পাবলিক রুট নেই';

  @override
  String get finishRideThenTap =>
      'একটি রাইড শেষ করুন, তারপর শেয়ার স্ক্রিনে \"রুট হিসেবে সেভ করুন\" ট্যাপ করুন।';

  @override
  String get publicRoutesOtherRiders =>
      'অন্য রাইডারদের সেভ করা পাবলিক রুট এখানে দেখা যাবে।';

  @override
  String routeRiddenSummary(Object distanceKm, Object timesRidden) {
    return '$distanceKm কিমি · $timesRidden বার চালানো';
  }

  @override
  String get thisRideHasNo =>
      'এই রাইডে রুট হিসেবে সেভ করার মতো কোনো ট্র্যাক নেই।';

  @override
  String get routeSaved => 'রুট সেভ হয়েছে';

  @override
  String get loadingTrack => 'ট্র্যাক লোড হচ্ছে…';

  @override
  String kmPoints(Object distanceKm, Object polylineCount) {
    return '$distanceKm কিমি · $polylineCountটি পয়েন্ট';
  }

  @override
  String get routeName => 'রুটের নাম';

  @override
  String get eGDhakaMawa => 'যেমন: ঢাকা – মাওয়া সকালের রাইড';

  @override
  String get giveRouteName => 'রুটটির একটি নাম দিন';

  @override
  String get roadSurfaceBestTime =>
      'রাস্তার অবস্থা, রাইডের সেরা সময়, কোথায় থামবেন…';

  @override
  String get saveRoute => 'রুট সেভ করুন';

  @override
  String get topSpeed => 'সর্বোচ্চ গতি';

  @override
  String get bestScore => 'সেরা স্কোর';

  @override
  String get allRides => 'সব রাইড';

  @override
  String get noRidesYetDot => 'এখনো কোনো রাইড নেই।';

  @override
  String showing(Object shownCount, Object sortedCount) {
    return '$sortedCountটির মধ্যে $shownCountটি দেখানো হচ্ছে';
  }

  @override
  String get distanceLower => 'দূরত্ব';

  @override
  String get topLower => 'সর্বোচ্চ';

  @override
  String hardBrakesRapidAccel(
      Object hardBrakeCount, Object rapidAccelCount, Object highJerkCount) {
    return '$hardBrakeCountটি হার্ড ব্রেক · $rapidAccelCountটি র‍্যাপিড এক্সেল · $highJerkCountটি ঝাঁকুনি';
  }

  @override
  String get journey => 'আপনার যাত্রা';

  @override
  String get goRideStartJourney => 'যাত্রা শুরু করতে একটি রাইডে বের হোন।';

  @override
  String get totalKm => 'মোট কিমি';

  @override
  String level(Object level, Object rank) {
    return 'লেভেল $level · $rank';
  }

  @override
  String get distanceOverTime => 'সময়ের সাথে দূরত্ব';

  @override
  String get avgSpeedOverTime => 'সময়ের সাথে গড় গতি';

  @override
  String badgesEarnedCount(Object earnedCount, Object badgesCount) {
    return '$badgesCountটির মধ্যে $earnedCountটি অর্জিত';
  }

  @override
  String get avgSpeedLower => 'গড় গতি';

  @override
  String get topSpeedLower => 'সর্বোচ্চ গতি';

  @override
  String get score => 'স্কোর';

  @override
  String get recentRides => 'সাম্প্রতিক রাইড';

  @override
  String get rides => 'আপনার রাইড';

  @override
  String shown(Object showing, Object total) {
    return '$totalটির মধ্যে $showingটি দেখানো হয়েছে';
  }

  @override
  String badgeFamilyEarned(
      Object family, Object earnedCount, Object badgesCount) {
    return '$family, $badgesCountটির মধ্যে $earnedCountটি অর্জিত';
  }

  @override
  String youProgress(Object progress, Object unit) {
    return 'আপনি: $progress $unit';
  }

  @override
  String nextGo(Object def, Object progress, Object unit) {
    return 'পরবর্তী: $def — আরও $progress $unit বাকি';
  }

  @override
  String get everyTierEarnedNothing =>
      'সব স্তর অর্জিত। এখানে আর কিছু বাকি নেই।';

  @override
  String earnedThreshold(Object threshold) {
    return 'অর্জিত। $threshold';
  }

  @override
  String youreAt(
      Object threshold, Object progress, Object threshold2, Object unit) {
    return '$threshold আপনি $threshold2 $unit-এর মধ্যে $progress-এ আছেন।';
  }

  @override
  String get notEnoughRidesYet => 'এখনো যথেষ্ট রাইড নেই';

  @override
  String get ridesAnalyticsTab => 'অ্যানালিটিক্স';

  @override
  String get ridesHistoryTab => 'ইতিহাস';

  @override
  String riderLevel(int level) {
    return 'লেভেল $level';
  }

  @override
  String get chartDistancePerRide => 'প্রতি রাইডে দূরত্ব';

  @override
  String get chartWeeklyDistance => 'প্রতি সপ্তাহে দূরত্ব';

  @override
  String get chartAvgSpeed => 'গড় গতি';

  @override
  String get chartTopSpeed => 'সর্বোচ্চ গতি';

  @override
  String get chartRideDuration => 'রাইডের সময়';

  @override
  String get chartMovingVsStopped => 'চলমান বনাম থেমে থাকা';

  @override
  String get chartJamTime => 'জ্যামে আটকে থাকার সময়';

  @override
  String get chartRidingScore => 'রাইডিং স্কোর';

  @override
  String get chartHardBraking => 'হার্ড ব্রেকিং';

  @override
  String get chartRapidAccel => 'দ্রুত অ্যাক্সিলারেশন';

  @override
  String get chartOverspeed => 'প্রতি রাইডে ওভারস্পিড সতর্কতা';

  @override
  String get chartActivityCalendar => 'রাইডের দিনগুলো';

  @override
  String get chartHourOfDay => 'দিনের কোন সময়ে রাইড';

  @override
  String get chartWeekday => 'সপ্তাহের কোন দিনে রাইড';

  @override
  String get chartDistanceByBike => 'প্রতি বাইকে দূরত্ব';

  @override
  String get chartLongestRides => 'সবচেয়ে লম্বা রাইড';

  @override
  String get analyticsRange7d => '7 দিন';

  @override
  String get analyticsRange30d => '30 দিন';

  @override
  String get analyticsRange90d => '90 দিন';

  @override
  String get analyticsRange1y => '1 বছর';

  @override
  String get analyticsRangeAll => 'সব';

  @override
  String get analyticsMin => 'সর্বনিম্ন';

  @override
  String get analyticsMax => 'সর্বোচ্চ';

  @override
  String get analyticsAvg => 'গড়';

  @override
  String get analyticsTotal => 'মোট';

  @override
  String get analyticsTrend => 'আগের তুলনায়';

  @override
  String get analyticsNoTrend => 'আগের তথ্য নেই';

  @override
  String get analyticsInsight => 'পর্যবেক্ষণ';

  @override
  String get analyticsData => 'তথ্য';

  @override
  String get analyticsDownloadData => 'তথ্য ডাউনলোড করুন';

  @override
  String get analyticsExportFailed => 'তথ্য এক্সপোর্ট করা যায়নি';

  @override
  String analyticsShareSubject(String chart) {
    return 'ThrottleIQ তথ্য: $chart';
  }

  @override
  String get analyticsColDate => 'তারিখ';

  @override
  String get analyticsColWeekOf => 'সপ্তাহ শুরু';

  @override
  String get analyticsColHour => 'ঘণ্টা';

  @override
  String get analyticsColDay => 'দিন';

  @override
  String get analyticsColBike => 'বাইক';

  @override
  String get analyticsColRides => 'রাইড';

  @override
  String get analyticsColMoving => 'চলমান';

  @override
  String get analyticsColStopped => 'থেমে থাকা';

  @override
  String get analyticsUnitMin => 'মিনিট';

  @override
  String get analyticsUnitRides => 'রাইড';

  @override
  String get analyticsUnitEvents => 'বার';

  @override
  String get analyticsUnknownBike => 'অজানা বাইক';

  @override
  String get analyticsTapForDetails => 'বিস্তারিত দেখতে চার্টে ট্যাপ করুন';

  @override
  String get insightNotEnoughData => 'এই সময়ে এখনো যথেষ্ট রাইড নেই।';

  @override
  String insightTrendUp(String percent) {
    return 'আগের সময়ের চেয়ে $percent% বেশি।';
  }

  @override
  String insightTrendDown(String percent) {
    return 'আগের সময়ের চেয়ে $percent% কম।';
  }

  @override
  String get insightTrendFlat => 'আগের সময়ের প্রায় সমান।';

  @override
  String insightPeakValue(String value, String date) {
    return 'সর্বোচ্চ ছিল $value, $date তারিখে।';
  }

  @override
  String insightPeakHour(String hour) {
    return 'আপনি সবচেয়ে বেশি রাইড করেন $hour এর দিকে।';
  }

  @override
  String insightPeakWeekday(String day) {
    return '$day আপনার সবচেয়ে বেশি রাইডের দিন।';
  }

  @override
  String insightTopBike(String bike, String percent) {
    return 'আপনার দূরত্বের $percent% $bike দিয়ে।';
  }

  @override
  String insightStreak(int current, int longest) {
    return 'আপনি টানা $current দিন রাইড করেছেন। আপনার রেকর্ড $longest দিন।';
  }

  @override
  String insightStreakRecordOnly(int longest) {
    return 'টানা রাইডের দিনে আপনার রেকর্ড $longest দিন।';
  }

  @override
  String insightLongestRide(String value, String date) {
    return 'আপনার সবচেয়ে লম্বা রাইড ছিল $value, $date তারিখে।';
  }

  @override
  String insightCleanRides(int clean, int total) {
    return '$totalটি রাইডের মধ্যে $cleanটিতে একবারও হয়নি।';
  }

  @override
  String insightStoppedShare(String percent) {
    return 'রাইডের সময়ের $percent% আপনি থেমে ছিলেন।';
  }

  @override
  String get cropPhoto => 'ছবি ক্রপ করুন';

  @override
  String get free => 'ফ্রি';

  @override
  String get couldNotOpenThat => 'ছবিটি খোলা যায়নি।';

  @override
  String get couldNotSaveCropped => 'ক্রপ করা ছবি সেভ করা যায়নি।';

  @override
  String get done => 'সম্পন্ন';

  @override
  String get rotate => 'ঘোরান';

  @override
  String get pleaseDescribeProblemBefore => 'পাঠানোর আগে সমস্যাটি বর্ণনা করুন।';

  @override
  String get couldNotSendReport => 'রিপোর্ট পাঠানো যায়নি। আবার চেষ্টা করুন।';

  @override
  String get describeWhatHappenedUid =>
      'কী হয়েছে বর্ণনা করুন। আপনার UID ও অ্যাপ ভার্সন নিজে থেকেই যুক্ত হবে।';

  @override
  String get eGMessagesWouldnt =>
      'যেমন: \"মেসেজ যাচ্ছিল না — পারমিশন নিয়ে একটি এরর পেয়েছি।\"';

  @override
  String get sending => 'পাঠানো হচ্ছে…';

  @override
  String get sendReport => 'রিপোর্ট পাঠান';

  @override
  String get startCaps => 'শুরু';

  @override
  String get finishCaps => 'শেষ';

  @override
  String waypoint(Object selectedPointIndex, Object polylineCount) {
    return '$polylineCountটির মধ্যে ওয়েপয়েন্ট #$selectedPointIndex';
  }

  @override
  String gpsPointsTapRoute(Object polylineCount) {
    return '$polylineCountটি GPS পয়েন্ট • ওয়েপয়েন্ট দেখতে রুটে ট্যাপ করুন';
  }

  @override
  String get saveRouteTitle => 'রুট সেভ করুন';

  @override
  String get dragMapMovePin => 'পিন সরাতে ম্যাপ টেনে আনুন';

  @override
  String get noRouteRecorded => 'কোনো রুট রেকর্ড হয়নি';

  @override
  String get sortRecent => 'সাম্প্রতিক';

  @override
  String importedPlaces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি জায়গা',
      one: '1টি জায়গা',
    );
    return 'OpenStreetMap থেকে $_temp0 ইম্পোর্ট হয়েছে';
  }

  @override
  String get errOffline =>
      'আপনি অফলাইনে আছেন। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।';

  @override
  String get errTimeout => 'এতে অনেক সময় লাগছে। সংযোগ দেখে আবার চেষ্টা করুন।';

  @override
  String get errNoPermission => 'এটি দেখার অনুমতি আপনার নেই।';

  @override
  String get errNotFound => 'এটি পাওয়া যায়নি — হয়তো সরিয়ে ফেলা হয়েছে।';

  @override
  String get errTooManyRequests =>
      'এই মুহূর্তে অনেক বেশি অনুরোধ। একটু পরে আবার চেষ্টা করুন।';

  @override
  String get errNotReady =>
      'এটি এখনো প্রস্তুত নয়। কয়েক মিনিট পর আবার চেষ্টা করুন।';

  @override
  String get errLoadGeneric => 'এটি লোড করতে সমস্যা হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get errUnknown => 'একটি অজানা ত্রুটি ঘটেছে';

  @override
  String get authUserNotFound =>
      'এই ইমেইলে কোনো অ্যাকাউন্ট পাওয়া যায়নি। আগে সাইন আপ করুন।';

  @override
  String get authWrongPassword => 'পাসওয়ার্ড ভুল। আবার চেষ্টা করুন।';

  @override
  String get authInvalidEmail => 'ইমেইল ঠিকানাটি সঠিক নয়।';

  @override
  String get authUserDisabled => 'এই অ্যাকাউন্টটি বন্ধ করে দেওয়া হয়েছে।';

  @override
  String get authOperationNotAllowed => 'ইমেইল দিয়ে সাইন ইন চালু নেই।';

  @override
  String get authTooManyRequests =>
      'অনেকবার লগইনের চেষ্টা হয়েছে। পরে আবার চেষ্টা করুন।';

  @override
  String get authInvalidCredential => 'ইমেইল বা পাসওয়ার্ড সঠিক নয়।';

  @override
  String get authEmailInUse => 'এই ইমেইলে আগে থেকেই একটি অ্যাকাউন্ট আছে।';

  @override
  String get authWeakPassword =>
      'পাসওয়ার্ড খুব দুর্বল। কমপক্ষে 6 অক্ষর ব্যবহার করুন।';

  @override
  String get authNetworkFailed => 'নেটওয়ার্ক সমস্যা। ইন্টারনেট সংযোগ দেখুন।';

  @override
  String get authAccountExistsDifferent =>
      'এই ইমেইলে অ্যাকাউন্ট আছে, কিন্তু সাইন ইনের পদ্ধতি আলাদা।';

  @override
  String get errNetworkFailed =>
      'নেটওয়ার্ক সংযোগ ব্যর্থ হয়েছে। ইন্টারনেট দেখুন।';

  @override
  String get errPermissionDenied =>
      'অনুমতি দেওয়া হয়নি। আপনার অ্যাকাউন্ট সেটিংস দেখুন।';

  @override
  String get errGeneric => 'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get errLocationOff =>
      'লোকেশন বন্ধ আছে। এই ফিচার ব্যবহার করতে ডিভাইস সেটিংসে GPS চালু করুন।';

  @override
  String get errLocationPermission =>
      'এই ফিচারের জন্য লোকেশন অনুমতি দরকার। সেটিংস → ThrottleIQ-তে গিয়ে অনুমতি দিন।';

  @override
  String get errLocationGeneric =>
      'আপনার লোকেশন পাওয়া যায়নি। GPS চালু আছে কিনা দেখে আবার চেষ্টা করুন।';

  @override
  String authGeneric(String error) {
    return 'সাইন ইন ত্রুটি: $error';
  }

  @override
  String get placeCatFuel => 'জ্বালানি';

  @override
  String get placeCatGarage => 'গ্যারেজ';

  @override
  String get placeCatParts => 'যন্ত্রাংশ';

  @override
  String get placeCatAiCamera => 'AI ক্যামেরা';

  @override
  String get placeCatPolice => 'পুলিশ / চেকপোস্ট';

  @override
  String get placeCatRecreation => 'বিনোদন';

  @override
  String get greetLateNight1 => 'গভীর রাতের রাইড, তাই না?';

  @override
  String get greetLateNight2 => 'এই সময়ে রাস্তা শুধু আপনার।';

  @override
  String get greetLateNight3 => 'ঘুম আসছে না? রাইডে বেরিয়ে পড়ুন।';

  @override
  String greetLateNight4(String name) {
    return 'ফাঁকা রাস্তা, $name।';
  }

  @override
  String get greetLateNight5 => 'বাইরে আপনি ছাড়া কেউ নেই।';

  @override
  String get greetEarlyMorning1 => 'জ্যামের আগেই বেরিয়ে পড়ুন।';

  @override
  String get greetEarlyMorning2 => 'ঠান্ডা ইঞ্জিন, পরিষ্কার রাস্তা।';

  @override
  String get greetEarlyMorning3 => 'ভোরের রাইডের মজাই আলাদা।';

  @override
  String greetEarlyMorning4(String name) {
    return 'এত ভোরে উঠেছেন, $name?';
  }

  @override
  String get greetEarlyMorning5 => 'সবার আগে বেরোলেন।';

  @override
  String greetMorning1(String name) {
    return 'সুপ্রভাত, $name।';
  }

  @override
  String get greetMorning2 => 'আপনি তৈরি হলেই আমরা তৈরি।';

  @override
  String get greetMorning3 => 'আগে কফি, তারপর বাঁক।';

  @override
  String get greetMorning4 => 'নতুন ট্যাংক, নতুন দিন।';

  @override
  String greetMorning5(String name) {
    return 'কোথায় যাচ্ছেন, $name?';
  }

  @override
  String greetAfternoon1(String name) {
    return 'শুভ অপরাহ্ন, $name।';
  }

  @override
  String get greetAfternoon2 => 'রাইডের জন্য দারুণ দিন।';

  @override
  String get greetAfternoon3 => 'রোদ উঠেছে, রাস্তাও খোলা।';

  @override
  String greetAfternoon4(String name) {
    return 'ঘরে ফিরতে লম্বা পথে, $name?';
  }

  @override
  String get greetAfternoon5 => 'একটু সরে পড়ার ঠিক সময়।';

  @override
  String greetEvening1(String name) {
    return 'শুভ সন্ধ্যা, $name।';
  }

  @override
  String get greetEvening2 => 'সোনালি আলো। চলুন।';

  @override
  String greetEvening3(String name) {
    return 'সূর্যাস্তের রাইড, $name?';
  }

  @override
  String get greetEvening4 => 'অফিস শেষ। গিয়ার পরে নিন।';

  @override
  String get greetEvening5 => 'দিনের সেরা আলো।';

  @override
  String get greetNight1 => 'নাইট রাইডার।';

  @override
  String get greetNight2 => 'ঘুমের আগে আরেকটা?';

  @override
  String greetNight3(String name) {
    return 'শান্ত রাস্তা, $name।';
  }

  @override
  String get greetNight4 => 'ঠান্ডা বাতাস, ফাঁকা লেন।';

  @override
  String greetNight5(String name) {
    return 'হেডলাইট জ্বালুন, $name।';
  }

  @override
  String get greetingNameFallback => 'রাইডার';

  @override
  String get quote0Setup => 'আপনার রাইড,';

  @override
  String get quote0Payoff => 'আরও স্মার্ট।';

  @override
  String get quote1Setup => 'দুই চাকা,';

  @override
  String get quote1Payoff => 'এক হৃদস্পন্দন।';

  @override
  String get quote2Setup => 'প্রতিটি রাইড,';

  @override
  String get quote2Payoff => 'লিখে রাখার মতো একটি গল্প।';

  @override
  String get quote3Setup => 'থ্রটলে ভরসা রাখুন,';

  @override
  String get quote3Payoff => 'রাস্তাকে সম্মান করুন।';

  @override
  String get quote4Setup => 'সামনের রাস্তাই';

  @override
  String get quote4Payoff => 'আপনার একমাত্র পরিকল্পনা।';

  @override
  String get quote5Setup => 'বাতাসে ভেসে চলুন,';

  @override
  String get quote5Payoff => 'রাস্তা আপনার।';

  @override
  String get quote6Setup => 'মসৃণই দ্রুত।';

  @override
  String get quote6Payoff => 'দ্রুতই মসৃণ।';

  @override
  String get quote7Setup => 'কিছু রাস্তা';

  @override
  String get quote7Payoff => 'ভোলা যায় না।';

  @override
  String get quote8Setup => 'দিগন্তের পেছনে ছুটুন,';

  @override
  String get quote8Payoff => 'রেডলাইনের নয়।';

  @override
  String get quote9Setup => 'মাইল পেরোলেই';

  @override
  String get quote9Payoff => 'মেশিন আপনার হয়।';

  @override
  String get quote10Setup => 'প্রতিটি গিয়ার বদল';

  @override
  String get quote10Payoff => 'একটি সিদ্ধান্ত।';

  @override
  String get quote11Setup => 'দূরে চলুন।';

  @override
  String get quote11Payoff => 'স্মার্টভাবে চলুন।';

  @override
  String get quote12Setup => 'সেরা রাইডগুলো';

  @override
  String get quote12Payoff => 'শুরু হয় কোনো পরিকল্পনা ছাড়াই।';

  @override
  String get quote13Setup => 'দুই চাকা,';

  @override
  String get quote13Payoff => 'অসীম রাস্তা।';

  @override
  String get quote14Setup => 'গতিই';

  @override
  String get quote14Payoff => 'এক ধরনের স্বাধীনতা।';

  @override
  String get quote15Setup => 'রাস্তাকে পড়ুন,';

  @override
  String get quote15Payoff => 'সে আপনাকে পড়ার আগেই।';

  @override
  String get noRatingsYet => 'এখনো কোনো রেটিং নেই';

  @override
  String get statusOverdue => 'ওভারডিউ';

  @override
  String get statusOk => 'ঠিক আছে';

  @override
  String get crashSuspectedBadge => 'সম্ভাব্য দুর্ঘটনা';

  @override
  String scoreValue(int score) {
    return 'স্কোর $score';
  }

  @override
  String get activePill => 'সক্রিয়';

  @override
  String get captionLabel => 'ক্যাপশন';

  @override
  String get commentsLabel => 'কমেন্ট';

  @override
  String get ridersLabel => 'রাইডার';

  @override
  String get rankNewRider => 'নতুন রাইডার';

  @override
  String get rankWeekendRider => 'সাপ্তাহিক রাইডার';

  @override
  String get rankSteadyCruiser => 'স্থির ক্রুজার';

  @override
  String get rankRoadRegular => 'নিয়মিত রাইডার';

  @override
  String get rankSeasonedRider => 'অভিজ্ঞ রাইডার';

  @override
  String get rankRoadMaster => 'রোড মাস্টার';

  @override
  String get tiersLabel => 'স্তর';

  @override
  String get rankVeteran => 'ভেটেরান';

  @override
  String get badgeFamFirstName => 'প্রথম রাইড';

  @override
  String get badgeFamFirstAbout =>
      'প্রতিটি রাইডারের শুরু — আপনার প্রথম রেকর্ড করা রাইড।';

  @override
  String get badgeFamFirstReq => 'আপনার প্রথম রাইডটি রেকর্ড করুন।';

  @override
  String get badgeRungFirstRide => 'প্রথম রাইড';

  @override
  String get badgeFamRidesName => 'রাইড';

  @override
  String get badgeFamRidesAbout =>
      'এ পর্যন্ত আপনি মোট কতগুলো রাইড রেকর্ড করেছেন।';

  @override
  String badgeFamRidesReq(String n) {
    return '$nটি রাইড রেকর্ড করুন।';
  }

  @override
  String get badgeRungRides10 => '10টি রাইড';

  @override
  String get badgeRungRides25 => '25টি রাইড';

  @override
  String get badgeRungRides50 => '50টি রাইড';

  @override
  String get badgeRungRides100 => '100টি রাইড';

  @override
  String get badgeRungRides250 => '250টি রাইড';

  @override
  String get badgeFamDistanceName => 'দূরত্ব';

  @override
  String get badgeFamDistanceAbout =>
      'আপনার রেকর্ড করা সব রাইড মিলিয়ে মোট অতিক্রান্ত দূরত্ব।';

  @override
  String badgeFamDistanceReq(String n) {
    return 'মোট $n কিমি রাইড করুন।';
  }

  @override
  String get badgeRungKm100 => '100 কিমি';

  @override
  String get badgeRungKm500 => '500 কিমি';

  @override
  String get badgeRungKm1000 => '1,000 কিমি';

  @override
  String get badgeRungKm2500 => '2,500 কিমি';

  @override
  String get badgeRungKm5000 => '5,000 কিমি';

  @override
  String get badgeFamLongRideName => 'সবচেয়ে লম্বা রাইড';

  @override
  String get badgeFamLongRideAbout =>
      'আপনার রেকর্ড করা একক সবচেয়ে লম্বা রাইডের দূরত্ব।';

  @override
  String badgeFamLongRideReq(String n) {
    return 'এক রাইডে $n কিমি পাড়ি দিন।';
  }

  @override
  String get badgeRungLongRide50 => 'ডে ট্রিপার';

  @override
  String get badgeRungLongRide100 => 'সেঞ্চুরি';

  @override
  String get badgeRungLongRide200 => 'লং হলার';

  @override
  String get badgeRungLongRide400 => 'ট্যুরার';

  @override
  String get badgeRungLongRide800 => 'আয়রন রাইডার';

  @override
  String get badgeFamSaddleTimeName => 'স্যাডল টাইম';

  @override
  String get badgeFamSaddleTimeAbout =>
      'আপনার রেকর্ড করা একক সবচেয়ে দীর্ঘ রাইডের সময়কাল।';

  @override
  String badgeFamSaddleTimeReq(String n) {
    return 'রেকর্ডিং বন্ধ না করে $n ঘণ্টা রাইড করুন।';
  }

  @override
  String get badgeRungSaddle1h => 'এক ঘণ্টা';

  @override
  String get badgeRungSaddle2h => 'দুই ঘণ্টা';

  @override
  String get badgeRungSaddle4h => 'চার ঘণ্টা';

  @override
  String get badgeRungSaddle8h => 'আট ঘণ্টা';

  @override
  String get badgeFamSpeedName => 'সর্বোচ্চ গতি';

  @override
  String get badgeFamSpeedAbout => 'আপনার সব রাইডে রেকর্ড করা সর্বোচ্চ গতি।';

  @override
  String badgeFamSpeedReq(String n) {
    return '$n কিমি/ঘণ্টা সর্বোচ্চ গতি রেকর্ড করুন।';
  }

  @override
  String get badgeRungTonUp => 'টন-আপ';

  @override
  String get badgeRungSpeed140 => 'কুইক';

  @override
  String get badgeRungSpeedDemon => 'স্পিড ডেমন';

  @override
  String get badgeFamNightName => 'নাইট রাইডার';

  @override
  String get badgeFamNightAbout =>
      'রাত 9টার পর বা ভোর 4টার আগে শুরু হওয়া রাইড।';

  @override
  String badgeFamNightReq(String n) {
    return 'রাত 9টা থেকে ভোর 4টার মধ্যে $nটি রাইড শুরু করুন।';
  }

  @override
  String get badgeRungNight1 => 'রাতের আঁধারে';

  @override
  String get badgeRungNight5 => 'নাইট আউল';

  @override
  String get badgeRungNight25 => 'মুনলাইটার';

  @override
  String get badgeRungNight50 => 'নিশাচর';

  @override
  String get badgeFamEarlyName => 'ভোরের পাখি';

  @override
  String get badgeFamEarlyAbout =>
      'ভোর 4টা থেকে সকাল 7টার মধ্যে শুরু হওয়া রাইড।';

  @override
  String badgeFamEarlyReq(String n) {
    return 'ভোর 4টা থেকে সকাল 7টার মধ্যে $nটি রাইড শুরু করুন।';
  }

  @override
  String get badgeRungEarly1 => 'সূর্যোদয়ের রাইড';

  @override
  String get badgeRungEarly5 => 'ভোরের পাখি';

  @override
  String get badgeRungEarly25 => 'ডন প্যাট্রোল';

  @override
  String get badgeFamStreakName => 'ধারাবাহিকতা';

  @override
  String get badgeFamStreakAbout =>
      'আপনার রেকর্ড করা রাইডসহ টানা কয়েক দিনের দীর্ঘতম ধারা।';

  @override
  String badgeFamStreakReq(String n) {
    return 'টানা $n দিন রাইড করুন।';
  }

  @override
  String get badgeRungStreak3 => '3 দিনের ধারা';

  @override
  String get badgeRungStreak7 => '7 দিনের ধারা';

  @override
  String get badgeRungStreak14 => '14 দিনের ধারা';

  @override
  String get badgeRungStreak30 => '30 দিনের ধারা';

  @override
  String get badgeFamSmoothName => 'মসৃণতা';

  @override
  String get badgeFamSmoothAbout =>
      'আপনার গড় রাইডিং স্কোর — কম হার্ড ব্রেক, র‍্যাপিড এক্সেলারেশন ও ঝাঁকুনিতে স্কোর বেশি হয়।';

  @override
  String badgeFamSmoothReq(String n) {
    return 'কমপক্ষে 5টি রাইডে গড়ে $n পয়েন্ট পান।';
  }

  @override
  String get badgeRungSmooth80 => 'স্থির হাত';

  @override
  String get badgeRungSmoothOperator => 'স্মুথ অপারেটর';

  @override
  String get badgeRungSmooth95 => 'সিল্ক';

  @override
  String get badgeRungSmooth98 => 'অনায়াস';

  @override
  String get badgeUnitRides => 'রাইড';

  @override
  String get badgeUnitKm => 'কিমি';

  @override
  String get badgeUnitHours => 'ঘণ্টা';

  @override
  String get badgeUnitKmh => 'কিমি/ঘণ্টা';

  @override
  String get badgeUnitDays => 'দিন';

  @override
  String get badgeUnitPts => 'পয়েন্ট';

  @override
  String get badgeTierBronze => 'ব্রোঞ্জ';

  @override
  String get badgeTierSilver => 'সিলভার';

  @override
  String get badgeTierGold => 'গোল্ড';

  @override
  String get badgeTierPlatinum => 'প্ল্যাটিনাম';

  @override
  String get badgeTierDiamond => 'ডায়মন্ড';

  @override
  String get turnStart => 'শুরু';

  @override
  String get turnSlightLeft => 'হালকা বাঁয়ে';

  @override
  String get turnLeft => 'বাঁয়ে ঘুরুন';

  @override
  String get turnSharpLeft => 'তীক্ষ্ণ বাঁয়ে';

  @override
  String get turnSlightRight => 'হালকা ডানে';

  @override
  String get turnRight => 'ডানে ঘুরুন';

  @override
  String get turnSharpRight => 'তীক্ষ্ণ ডানে';

  @override
  String get turnUTurn => 'ইউ-টার্ন নিন';

  @override
  String get turnStraight => 'সোজা চলুন';

  @override
  String get turnArrive => 'আপনি পৌঁছে গেছেন';

  @override
  String get compassNorth => 'উত্তর';

  @override
  String get compassNorthEast => 'উত্তর-পূর্ব';

  @override
  String get compassEast => 'পূর্ব';

  @override
  String get compassSouthEast => 'দক্ষিণ-পূর্ব';

  @override
  String get compassSouth => 'দক্ষিণ';

  @override
  String get compassSouthWest => 'দক্ষিণ-পশ্চিম';

  @override
  String get compassWest => 'পশ্চিম';

  @override
  String get compassNorthWest => 'উত্তর-পশ্চিম';

  @override
  String turnHead(String direction) {
    return '$direction দিকে যান';
  }

  @override
  String get notifChannelCrash => 'দুর্ঘটনার সতর্কতা';

  @override
  String get notifChannelCrashDesc =>
      'ThrottleIQ মনে করলে আপনি দুর্ঘটনায় পড়েছেন, তখন দেখানো হয়। এটি বন্ধ করবেন না।';

  @override
  String get notifChannelRides => 'রাইড নিশ্চিতকরণ';

  @override
  String get notifChannelRidesDesc =>
      'অটো-শনাক্ত রাইডটি কোন বাইকে ছিল তা জিজ্ঞেস করে।';

  @override
  String get notifChannelDigest => 'সাপ্তাহিক ডাইজেস্ট';

  @override
  String get notifChannelDigestDesc => 'আপনার সাপ্তাহিক রাইডিংয়ের সারসংক্ষেপ।';

  @override
  String get notifCrashTitle => 'দুর্ঘটনা শনাক্ত হয়েছে';

  @override
  String notifCrashBody(int seconds) {
    return 'আপনি \"আমি ঠিক আছি\"-তে ট্যাপ না করলে $seconds সেকেন্ডের মধ্যে আপনার জরুরি কন্টাক্টদের জানানো হবে।';
  }

  @override
  String get notifImOk => 'আমি ঠিক আছি';

  @override
  String notifRideDetectedTitle(String km) {
    return 'রাইড শনাক্ত হয়েছে — $km কিমি';
  }

  @override
  String notifRideDetectedBody(String bike) {
    return '$bike-এ এটি লগ করা হয়েছে। নিশ্চিত করতে বা বদলাতে ট্যাপ করুন।';
  }

  @override
  String get notifConfirm => 'নিশ্চিত করুন';

  @override
  String get notifDigestTitle => 'আজ রাস্তায়';

  @override
  String get notifDigestTap => 'আপনার দিনটি দেখতে ট্যাপ করুন।';

  @override
  String notifDigestSummary(int rides, String km) {
    String _temp0 = intl.Intl.pluralLogic(
      rides,
      locale: localeName,
      other: '$ridesটি রাইড',
      one: '1টি রাইড',
    );
    return '$_temp0, $km কিমি';
  }

  @override
  String notifDigestUnconfirmed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটিতে বাইক নিশ্চিত করা দরকার',
      one: '1টিতে বাইক নিশ্চিত করা দরকার',
    );
    return ' · $_temp0';
  }

  @override
  String get shareUsageStats => 'অজ্ঞাতনামা ব্যবহারের পরিসংখ্যান শেয়ার করুন';

  @override
  String get shareUsageStatsDesc =>
      'কোন স্ক্রিন ব্যবহার হয় এবং রাইড শুরুর মতো কয়েকটি ধাপ। আপনার লোকেশন, রাইড, মেসেজ বা নাম কখনোই নয় — কোনো বিজ্ঞাপনও নয়।';

  @override
  String get safeQrPrintAction => 'স্টিকার প্রিন্ট করুন';

  @override
  String get safeQrStickerTitle => 'জরুরি মেডিকেল তথ্য';

  @override
  String get safeQrStickerCaption =>
      'যেকোনো ফোনের ক্যামেরা দিয়ে স্ক্যান করুন। অফলাইনেও কাজ করে।';

  @override
  String get safeQrPrintFailed => 'প্রিন্ট ডায়ালগ খোলা যায়নি।';

  @override
  String get feedSortHot => 'জনপ্রিয়';

  @override
  String get joinRideBadCode => 'এই কোডের সাথে কোনো রাইড মেলেনি।';

  @override
  String get joinRideAlreadyEnded => 'এই রাইডটি ইতিমধ্যে শেষ হয়ে গেছে।';

  @override
  String get joinRideFull => 'এই রাইডে আর জায়গা নেই।';

  @override
  String get joinRideRemoved =>
      'রাইডের আয়োজক আপনাকে এই রাইড থেকে সরিয়ে দিয়েছেন।';

  @override
  String groupRideTooManyFriends(Object max) {
    return 'আপনি একসাথে সর্বোচ্চ $max জন বন্ধুর সাথে রাইড করতে পারবেন।';
  }

  @override
  String get groupRidePickAtLeastOne =>
      'রাইড করার জন্য অন্তত 1 জন রাইডার বেছে নিন।';

  @override
  String groupRidePickAtLeastMany(Object min, Object short) {
    return 'অন্তত $min জন রাইডার বেছে নিন — আরও $short জন বাকি।';
  }

  @override
  String get usernameRuleError =>
      'ইউজারনেম 3-20 অক্ষরের হতে হবে: অক্ষর, সংখ্যা বা আন্ডারস্কোর।';

  @override
  String get groupRideTalkButton => 'গ্রুপ টক';

  @override
  String get groupRideLiveBannerTitle => 'আপনি একটি লাইভ গ্রুপ রাইডে আছেন';

  @override
  String get groupRideLiveBannerAction => 'পুশ-টু-টক খুলুন';

  @override
  String get groupRideRideStats => 'রাইডের তথ্য';

  @override
  String get maintSettingsTitle => 'রক্ষণাবেক্ষণ সেটিংস';

  @override
  String get maintCustomizeChecks => 'চেক কাস্টমাইজ করুন';

  @override
  String get maintCustomizeChecksSubtitle =>
      'কী ট্র্যাক করবেন এবং কত ঘন ঘন, বেছে নিন';

  @override
  String get maintSyncOdometer => 'ওডোমিটার সিঙ্ক';

  @override
  String get maintSyncOdometerSubtitle =>
      'অ্যাপকে বাইকের আসল রিডিংয়ের সাথে মেলান';

  @override
  String get maintResetLogSubtitle =>
      'একসাথে কয়েকটি আইটেম সার্ভিস করা হিসেবে চিহ্নিত করুন';

  @override
  String get maintDistanceUnits => 'দূরত্বের একক';

  @override
  String get maintRunningCosts => 'চলার খরচ';

  @override
  String get maintRunningCostsEmpty =>
      'প্রতিটি রাইডের খরচ দেখতে জ্বালানির দাম, মাইলেজ ও সার্ভিস খরচ সেট করুন';

  @override
  String maintCostPerUnit(String cost, String unit) {
    return '≈ প্রতি $unit ৳$cost';
  }

  @override
  String get maintFuelPricePerLitre => 'প্রতি লিটারের দাম';

  @override
  String get maintFuelPricePerGallon => 'প্রতি গ্যালনের দাম';

  @override
  String get maintAverageMileage => 'গড় মাইলেজ';

  @override
  String get maintServiceCosts => 'সার্ভিস খরচ';

  @override
  String get maintServiceCostsHint =>
      'আইটেমে ট্যাপ করে সাধারণ খরচ সেট করুন। খরচসহ সার্ভিস লগ করলে সেগুলোর গড় ব্যবহার হবে।';

  @override
  String get maintTypicalCost => 'প্রতি সার্ভিসে সাধারণ খরচ';

  @override
  String get maintTypicalCostHelper =>
      'আসল খরচ লগ না করা পর্যন্ত রাইডের খরচ অনুমানে ব্যবহার হয়।';

  @override
  String maintCostFromHistory(String cost) {
    return 'লগ করা গড় ৳$cost';
  }

  @override
  String maintCostFromTypical(String cost) {
    return 'সাধারণ ৳$cost';
  }

  @override
  String get maintCostNotSet => 'খরচ সেট করা হয়নি';

  @override
  String get rideCostTitle => 'রাইডের খরচ';

  @override
  String get rideCostHint =>
      'এই রাইডে কত খরচ হলো দেখতে জ্বালানির দাম, মাইলেজ ও সার্ভিস খরচ যোগ করুন।';

  @override
  String get rideCostSetUp => 'সেট করুন';

  @override
  String rideCostEstimateNote(String distance, String perKm) {
    return 'অনুমান · $distance কিমি, ৳$perKm/কিমি';
  }

  @override
  String get partOrderButton => 'অর্ডার';

  @override
  String partOrderTitle(String part) {
    return '$part অর্ডার করুন';
  }

  @override
  String get partOrderTestingNotice =>
      'এই ফিচারটি পরীক্ষা করা হচ্ছে। কোনো আসল অর্ডার হবে না এবং কোনো টাকা কাটা হবে না।';

  @override
  String get partOrderCod => 'ক্যাশ অন ডেলিভারি';

  @override
  String get partOrderName => 'আপনার নাম';

  @override
  String get partOrderPhone => 'ফোন নম্বর';

  @override
  String get partOrderAddress => 'ডেলিভারির ঠিকানা';

  @override
  String get partOrderQuantity => 'পরিমাণ';

  @override
  String get partOrderRequired => 'আবশ্যক';

  @override
  String get partOrderPlace => 'ডেমো অর্ডার দিন';

  @override
  String get partOrderPlacedTitle => 'ডেমো অর্ডার নথিভুক্ত হয়েছে';

  @override
  String get partOrderPlacedBody =>
      'এই ফিচারটি পরীক্ষা করা হচ্ছে। কোনো অর্ডার দেওয়া হয়নি এবং কোনো টাকা কাটা হয়নি।';

  @override
  String get noOtherRidersYet => 'এখনো দেখানোর মতো অন্য কোনো রাইডার নেই।';

  @override
  String get loadMore => 'আরও লোড করুন';

  @override
  String get loadOlderMessages => 'পুরনো মেসেজ লোড করুন';

  @override
  String get jamLabelStart => 'আমি জ্যামে আছি';

  @override
  String get jamLabelRelease => 'জ্যাম ছেড়েছে';

  @override
  String get jamLabelBetaTag => 'বেটা';

  @override
  String notifDigestRideTime(int minutes) {
    return ' · $minutes মিনিট রাইড';
  }

  @override
  String notifDigestNotRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি রেকর্ড করা হয়নি',
      one: '1টি রেকর্ড করা হয়নি',
    );
    return ' · $_temp0';
  }

  @override
  String get autoSummaryTodayTitle => 'আজ';

  @override
  String autoSummaryRides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি রাইড',
      one: '1টি রাইড',
      zero: 'এখনো কোনো রাইড নেই',
    );
    return '$_temp0';
  }

  @override
  String autoSummaryStats(String km, int minutes, int jamMinutes) {
    return '$km কিমি · $minutes মিনিট রাইড · $jamMinutes মিনিট জ্যামে থেমে';
  }

  @override
  String autoSummaryNotRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'রেকর্ড না করা $countটি রাইড সহ',
      one: 'রেকর্ড না করা 1টি রাইড সহ',
    );
    return '$_temp0';
  }

  @override
  String get dailySummariesTitle => 'দৈনিক রাইডের সারাংশ';

  @override
  String get dailySummariesSubtitle =>
      'অটো-ট্র্যাকিংয়ে ধরা রাইড জ্যামের বিরতি পেরিয়ে জোড়া লাগানো হয় এবং প্রতিটি যাত্রা একবারই গোনা হয়, আপনার রেকর্ড করা রাইডসহ।';

  @override
  String get dailySummariesEmpty => 'গত দুই সপ্তাহে কোনো রাইড নেই।';

  @override
  String adaptHardBraking(String rate, int pct) {
    return 'জোরে ব্রেক $rate/100 কিমি · −$pct%';
  }

  @override
  String adaptSevereRoads(int pct) {
    return 'ধুলো বা ভেজা রাস্তা · −$pct%';
  }

  @override
  String adaptStopAndGo(int share, int pct) {
    return 'থেমে থেমে চলা $share% · −$pct%';
  }

  @override
  String adaptedTo(String km) {
    return 'আপনার চালানো অনুযায়ী: প্রতি $km';
  }

  @override
  String get addCustomCheck => 'নিজের একটি চেক যোগ করুন';

  @override
  String get advanceWarning => 'আগাম সতর্কতা';

  @override
  String get advanceWarningHelper =>
      'কখন থেকে \"শীঘ্রই সার্ভিস\" দেখাবে। ডিফল্টের জন্য ফাঁকা রাখুন।';

  @override
  String get allGoodNothingDue => 'সব ঠিক আছে, কিছুই বাকি নেই';

  @override
  String allGoodUntil(String date) {
    return '~$date পর্যন্ত সব ঠিক আছে';
  }

  @override
  String atOdometer(String km) {
    return '$km-এ';
  }

  @override
  String get bundleBrakeService => 'ব্রেক সার্ভিস';

  @override
  String get bundleChainCare => 'চেইনের যত্ন';

  @override
  String get bundleGeneralService => 'সাধারণ সার্ভিসিং';

  @override
  String get bundleOilChange => 'মবিল পরিবর্তন';

  @override
  String get checkNotTracked =>
      'ট্র্যাক করা হচ্ছে না। রিমাইন্ডার পেতে চেক কাস্টমাইজে এটি চালু করুন।';

  @override
  String comingUpNextDays(int days) {
    return 'আসছে · পরের $days দিন';
  }

  @override
  String costPerUnitLabel(String unit) {
    return 'প্রতি $unit, সব মিলিয়ে';
  }

  @override
  String costTrend(String first, String latest, String avg) {
    return 'প্রথম $first → সর্বশেষ $latest · গড় $avg';
  }

  @override
  String get countingFromBaseline => 'গণনা শুরু: ';

  @override
  String get customCheckName => 'চেকের নাম';

  @override
  String get customChecksSection => 'আপনার নিজের চেক';

  @override
  String daysShort(int days) {
    return '$days দিন';
  }

  @override
  String get daysUnit => 'দিন';

  @override
  String deleteVisitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'এটি এই ভিজিটে লগ করা $countটি আইটেম এখানে ও ক্লাউডে মুছে দেবে।',
      one: 'এটি লগ করা আইটেমটি এখানে ও ক্লাউডে মুছে দেবে।',
    );
    return '$_temp0';
  }

  @override
  String get deleteVisitTitle => 'ভিজিট মুছবেন?';

  @override
  String get doneIt => 'করা হয়েছে';

  @override
  String dueInDays(int days) {
    return '~$days দিনে';
  }

  @override
  String get dueOverdue => 'সময় পেরিয়ে গেছে';

  @override
  String get dueToday => 'আজ করতে হবে';

  @override
  String get dueTomorrow => 'আগামীকাল';

  @override
  String get editInterval => 'ব্যবধান বদলান';

  @override
  String get editVisitTitle => 'ভিজিট সম্পাদনা';

  @override
  String everyNDays(int days) {
    return 'প্রতি $days দিনে';
  }

  @override
  String get exportFailed =>
      'সার্ভিস রেকর্ড তৈরি করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get exportNothingYet =>
      'আগে একটি সার্ভিস লগ করুন। এখনো এক্সপোর্ট করার কিছু নেই।';

  @override
  String get exportServiceRecord => 'সার্ভিস রেকর্ড এক্সপোর্ট';

  @override
  String get exportServiceRecordSubtitle =>
      'প্রতিটি ভিজিট ও রসিদের PDF, ক্রেতা বা মেকানিকের জন্য';

  @override
  String freeServiceN(int n) {
    return 'ফ্রি সার্ভিস #$n';
  }

  @override
  String freeServicesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ওয়ারেন্টিতে $countটি ফ্রি সার্ভিস:',
      one: 'ওয়ারেন্টিতে 1টি ফ্রি সার্ভিস:',
    );
    return '$_temp0';
  }

  @override
  String get fromGallery => 'গ্যালারি';

  @override
  String groupAllGood(int count) {
    return 'সব ঠিক · $count';
  }

  @override
  String groupComingUp(int count) {
    return 'আসছে · $count';
  }

  @override
  String groupNeedsAttention(int count) {
    return 'মনোযোগ দরকার · $count';
  }

  @override
  String groupUnknown(int count) {
    return 'এখনো জানা নেই · $count';
  }

  @override
  String get intervalDaysLabel => 'অথবা প্রতি (দিন)';

  @override
  String get intervalNeedKmOrDays => 'দূরত্ব, দিনের সংখ্যা, অথবা দুটোই লিখুন';

  @override
  String get intervalSection => 'ব্যবধান';

  @override
  String get intervalSourceTemplate => 'আপনার বাইকের সার্ভিস সূচি থেকে';

  @override
  String get intervalSourceUser => 'আপনার ঠিক করা';

  @override
  String get intervalWhicheverFirst => 'যেটি আগে আসে তখনই সার্ভিস।';

  @override
  String get itemHistory => 'ইতিহাস';

  @override
  String lastServiceLine(String details) {
    return 'শেষবার: $details';
  }

  @override
  String get lastServicedLabel => 'শেষ করা হয়েছে: ';

  @override
  String limitsByDate(String date) {
    return '$date-এর মধ্যে';
  }

  @override
  String limitsKmOrDate(String km, String date) {
    return '$km অথবা $date, যেটি আগে';
  }

  @override
  String get logItNow => 'এখনই লগ করুন';

  @override
  String get logVisitTitle => 'ভিজিট লগ করুন';

  @override
  String get maintAdaptSubtitle =>
      'থেমে থেমে চলা, জোরে ব্রেক ও খারাপ রাস্তার জন্য ব্যবধান কমান';

  @override
  String get maintAdaptTitle => 'আমার চালানো অনুযায়ী মানিয়ে নিন';

  @override
  String maintAlertDueSoon(String item) {
    return '$item শীঘ্রই করতে হবে';
  }

  @override
  String maintAlertOverdue(String item) {
    return '$item-এর সময় পেরিয়ে গেছে';
  }

  @override
  String get maintDueToday => 'আজ করতে হবে';

  @override
  String maintLeftDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days দিন বাকি',
      one: '1 দিন বাকি',
    );
    return '$_temp0';
  }

  @override
  String maintLeftKm(String km) {
    return '$km বাকি';
  }

  @override
  String maintLeftKmOrDays(String km, int days) {
    return '$km অথবা $days দিন বাকি, যেটি আগে আসে';
  }

  @override
  String maintOverDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days দিন আগে করার কথা ছিল',
      one: 'গতকাল করার কথা ছিল',
    );
    return '$_temp0';
  }

  @override
  String maintOverKm(String km) {
    return '$km বেশি হয়ে গেছে';
  }

  @override
  String get maintRemindersSubtitle =>
      'কিছু করার সময় হলে এবং কাগজের মেয়াদ শেষের আগে জানান';

  @override
  String get maintRemindersTitle => 'মেইনটেন্যান্স রিমাইন্ডার';

  @override
  String get maintScheduleNotSet =>
      'সেট আপ করা হয়নি। বাইকের সার্ভিস সূচি বেছে নিতে ট্যাপ করুন';

  @override
  String get maintScheduleTitle => 'সার্ভিস সূচি ও রাস্তার অবস্থা';

  @override
  String get maintUnknownStatus => 'এখনো জানা নেই। শেষ কবে করা হয়েছে লিখুন';

  @override
  String get markFixed => 'ঠিক করা হয়েছে';

  @override
  String get moneyTitle => 'চালানোর খরচ';

  @override
  String nextDueLine(String item, String when) {
    return 'পরবর্তী: $item · $when';
  }

  @override
  String nextUpIs(String item) {
    return 'পরবর্তী: $item';
  }

  @override
  String get notSure => 'নিশ্চিত নই';

  @override
  String get notifChannelMaintenance => 'মেইনটেন্যান্স';

  @override
  String get notifChannelMaintenanceDesc =>
      'সার্ভিস রিমাইন্ডার ও কাগজপত্রের মেয়াদ';

  @override
  String get odometerAtThatTime => 'তখন ওডোমিটারে কত ছিল';

  @override
  String get oilBrandLabel => 'যে মবিল দেওয়া হয়েছে';

  @override
  String get oilDetails => 'ইঞ্জিন অয়েল';

  @override
  String get oilGradeFull => 'ফুল সিনথেটিক';

  @override
  String oilGradeInterval(String km, int days) {
    return 'প্রায় প্রতি $km কিমি বা $days দিনে বদলান';
  }

  @override
  String get oilGradeMineral => 'মিনারেল';

  @override
  String oilGradeNextChange(String km, int days) {
    return 'পরের মবিল পরিবর্তন $km কিমি বা $days দিনে';
  }

  @override
  String get oilGradeSemi => 'সেমি-সিনথেটিক';

  @override
  String get oneOffJob => 'অন্য কিছু (একবারের কাজ)';

  @override
  String get orJoiner => ' অথবা ';

  @override
  String paperworkAlertExpired(String doc) {
    return '$doc-এর মেয়াদ শেষ';
  }

  @override
  String paperworkAlertExpiring(String doc, int days) {
    return '$doc-এর মেয়াদ $days দিনে শেষ হবে';
  }

  @override
  String get paperworkDrivingLicence => 'ড্রাইভিং লাইসেন্স';

  @override
  String get paperworkEmpty =>
      'ট্যাক্স টোকেন, ইন্সুরেন্স ও অন্য কাগজ যোগ করুন, মেয়াদ শেষের আগে মনে করিয়ে দেওয়া হবে।';

  @override
  String paperworkExpiredOn(String date) {
    return '$date-এ মেয়াদ শেষ হয়েছে';
  }

  @override
  String paperworkExpiresOn(String date, int days) {
    return 'মেয়াদ $date · $days দিন বাকি';
  }

  @override
  String paperworkExpiryValue(String date) {
    return 'মেয়াদ $date';
  }

  @override
  String get paperworkFitness => 'ফিটনেস সার্টিফিকেট';

  @override
  String get paperworkInsurance => 'ইন্সুরেন্স';

  @override
  String get paperworkPickExpiry => 'মেয়াদ শেষের তারিখ বাছুন';

  @override
  String get paperworkRegistration => 'রেজিস্ট্রেশন';

  @override
  String get paperworkTaxToken => 'ট্যাক্স টোকেন';

  @override
  String get paperworkTitle => 'কাগজপত্র';

  @override
  String perKmBreakdown(String maint, String fuel) {
    return 'সার্ভিসিং $maint + জ্বালানি $fuel';
  }

  @override
  String get pickDateOptional => 'তারিখ (ঐচ্ছিক)';

  @override
  String get precheckAllGood => 'সব ঠিক আছে';

  @override
  String get precheckChain => 'চেইন';

  @override
  String get precheckChainHint =>
      'প্রায় 2–3 সেমি ঢিল, লুব দেওয়া, কোথাও টাইট নয়';

  @override
  String get precheckControls => 'কন্ট্রোল';

  @override
  String get precheckControlsHint =>
      'ব্রেক, ক্লাচ, থ্রটল ও তার মসৃণভাবে কাজ করে';

  @override
  String get precheckInstructions =>
      'বাইকের চারপাশ ঘুরে দেখুন, যা ঠিক নেই তাতে ট্যাপ করুন। প্রায় 30 সেকেন্ড।';

  @override
  String precheckIssueFlagged(String date) {
    return 'দ্রুত চেকে ধরা পড়েছে · $date';
  }

  @override
  String precheckLastDone(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'শেষ চেক $days দিন আগে',
      one: 'শেষ চেক গতকাল',
      zero: 'আজ চেক করা হয়েছে',
    );
    return '$_temp0';
  }

  @override
  String get precheckLights => 'লাইট';

  @override
  String get precheckLightsHint => 'হেডলাইট, টেইল, ব্রেক লাইট, ইন্ডিকেটর, হর্ন';

  @override
  String get precheckNeedsWork => 'মনোযোগ দরকার';

  @override
  String get precheckNever => 'সপ্তাহে একবার 30 সেকেন্ডের পরীক্ষা';

  @override
  String get precheckOil => 'মবিল ও তরল';

  @override
  String get precheckOilHint =>
      'জানালায় মবিলের লেভেল, কোনো লিক নেই, ব্রেক ফ্লুইড MIN-এর উপরে';

  @override
  String precheckSaveIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি সমস্যা সেভ করুন',
      one: '1টি সমস্যা সেভ করুন',
    );
    return '$_temp0';
  }

  @override
  String get precheckStands => 'স্ট্যান্ড';

  @override
  String get precheckStandsHint => 'সাইড ও সেন্টার স্ট্যান্ড ঠিকমতো ফিরে আসে';

  @override
  String get precheckTires => 'টায়ার ও চাকা';

  @override
  String get precheckTiresHint => 'হাওয়া, গ্রিপ, কাটা বা ফোলা নেই';

  @override
  String get precheckTitle => 'দ্রুত চেক';

  @override
  String projectedDue(String date, String when) {
    return 'আনুমানিক: $date ($when)';
  }

  @override
  String get quickPicks => 'দ্রুত বাছাই';

  @override
  String get receiptLabel => 'রসিদ';

  @override
  String get receiptPickFailed => 'ছবিটি যোগ করা যায়নি।';

  @override
  String get remindMeLater => 'পরে মনে করিয়ে দিন';

  @override
  String get removeCheck => 'চেক সরান';

  @override
  String get ridingProfileNormal => 'বেশিরভাগ পাকা রাস্তা';

  @override
  String get ridingProfileNormalHelper =>
      'মোটামুটি ভালো রাস্তায় শহর ও হাইওয়েতে চালানো।';

  @override
  String get ridingProfileSevere => 'ধুলো, পানি বা ভাঙা রাস্তা';

  @override
  String get ridingProfileSevereHelper =>
      'নির্মাণের ধুলো, জলাবদ্ধ রাস্তা, খারাপ গ্রামের রাস্তা। এয়ার ফিল্টার ও চেইনের সার্ভিস আগে লাগবে।';

  @override
  String rowLeftDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days দিন বাকি',
      one: '1 দিন বাকি',
    );
    return '$_temp0';
  }

  @override
  String rowLeftKm(String km) {
    return '$km বাকি';
  }

  @override
  String rowLeftKmOrDays(String km, int days) {
    return '$km অথবা $days দিন বাকি';
  }

  @override
  String rowOverBy(String km) {
    return '$km বেশি';
  }

  @override
  String rowOverDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days দিন পেরিয়ে গেছে',
      one: '1 দিন পেরিয়ে গেছে',
      zero: 'আজ করতে হবে',
    );
    return '$_temp0';
  }

  @override
  String saveVisitN(int count) {
    return 'ভিজিট সেভ করুন · $countটি আইটেম';
  }

  @override
  String get scheduleApproximate => 'আনুমানিক';

  @override
  String get scheduleVerified => 'ম্যানুয়াল থেকে';

  @override
  String get serviceRecordColCost => 'খরচ';

  @override
  String get serviceRecordColDate => 'তারিখ';

  @override
  String get serviceRecordColOdometer => 'ওডোমিটার';

  @override
  String get serviceRecordColShop => 'ওয়ার্কশপ';

  @override
  String get serviceRecordColWork => 'যে কাজ হয়েছে';

  @override
  String get serviceRecordFooter =>
      'মালিকের নিজের রেকর্ড থেকে ThrottleIQ দিয়ে তৈরি';

  @override
  String serviceRecordGenerated(String date) {
    return 'তৈরির তারিখ $date';
  }

  @override
  String get serviceRecordTitle => 'সার্ভিস রেকর্ড';

  @override
  String serviceRecordTotal(int count, String total) {
    return '$countটি ভিজিট · মোট ৳$total';
  }

  @override
  String get serviceVisit => 'সার্ভিস ভিজিট';

  @override
  String get setLastDone => 'শেষ কবে করা হয়েছে';

  @override
  String get setLastDoneHelper =>
      'আনুমানিক হলেই চলবে। এখান থেকেই গণনা শুরু হবে।';

  @override
  String setLastDoneTitle(String item) {
    return '$item শেষ কবে করা হয়েছিল?';
  }

  @override
  String get setupCardBody =>
      'বাইকের সার্ভিস সূচি বাছুন এবং শেষ কবে মবিল বদলানো হয়েছে জানান, তাহলে প্রতিটি তারিখ সঠিক হবে।';

  @override
  String get setupCardTitle => 'মেইনটেন্যান্স সেট আপ করুন';

  @override
  String get setupLastOilQuestion => 'শেষ কবে মবিল বদলানো হয়েছে?';

  @override
  String get setupOilLabel => 'ইঞ্জিন অয়েল';

  @override
  String get setupOilUnknown => 'আমি জানি না';

  @override
  String get setupOthersSame => 'ওই সার্ভিসে বাকি সবকিছুও করা হয়েছিল';

  @override
  String get setupResetIntervals =>
      'প্রতিটি চেকে এই সূচির ব্যবধান ব্যবহার করুন';

  @override
  String get setupResetIntervalsHelper =>
      'আপনার বদলানো ব্যবধান মুছে যাবে। বন্ধ রাখলে আপনার পরিবর্তন থাকবে।';

  @override
  String get setupRoadsLabel => 'আপনার রাস্তা';

  @override
  String get setupSave => 'সেভ করে মেইনটেন্যান্স দেখান';

  @override
  String get setupScheduleLabel => 'সার্ভিস সূচি';

  @override
  String get setupTelemetryNote =>
      'যানজট ও ব্রেকিং আপনার রাইড থেকে মাপা হয়। সেটিংসে এটি বন্ধ করতে পারেন।';

  @override
  String get setupTitle => 'মেইনটেন্যান্স সেটআপ';

  @override
  String get shopKindAuthorized => 'সার্ভিস সেন্টার';

  @override
  String get shopKindLocal => 'লোকাল মেকানিক';

  @override
  String get shopKindSelf => 'নিজে করেছি';

  @override
  String get shopNameHint => 'যেমন রহিম মোটরস, ACI 3S মিরপুর';

  @override
  String get shopNameLabel => 'কোথায়';

  @override
  String get showAllItems => 'সব আইটেম দেখান';

  @override
  String showMoreVisits(int count) {
    return 'আরও $countটি দেখান';
  }

  @override
  String get showTrackedOnly => 'শুধু ট্র্যাক করা দেখান';

  @override
  String snoozedFor(int days) {
    return 'ঠিক আছে, $days দিন পর আবার দেখানো হবে।';
  }

  @override
  String get spendOil => 'মবিল ও ফিল্টার';

  @override
  String get spendParts => 'অন্য পার্টস ও কাজ';

  @override
  String get spendVisits => 'সার্ভিসিং (আলাদা করা নয়)';

  @override
  String get spentLast12Months => 'গত 12 মাসে খরচ';

  @override
  String get statusUnknown => 'অজানা';

  @override
  String get today => 'আজ';

  @override
  String get undo => 'ফিরিয়ে নিন';

  @override
  String get upNext => 'পরবর্তী কাজ';

  @override
  String get visitDetails => 'ভিজিটের বিবরণ';

  @override
  String get visitPickSomething => 'অন্তত একটি করা কাজে টিক দিন।';

  @override
  String visitSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি আইটেম লগ হয়েছে',
      one: '1টি আইটেম লগ হয়েছে',
    );
    return '$_temp0';
  }

  @override
  String get visitTotalCost => 'মোট বিল (ঐচ্ছিক)';

  @override
  String get visitUpdated => 'ভিজিট আপডেট হয়েছে';

  @override
  String get warnDaysBefore => 'কত দিন আগে';

  @override
  String get warnKmBefore => 'কত কিমি আগে';

  @override
  String get whatWasDone => 'কী করা হয়েছে';

  @override
  String get odometerPhotoHelper => 'ছবিতে যে রিডিং দেখা যাচ্ছে সেটি লিখুন।';

  @override
  String get forumPulse => 'পালস';

  @override
  String get forumHubs => 'হাব';

  @override
  String get pulseFilterAll => 'সব';

  @override
  String get pulseFilterMyBikes => 'আমার বাইক';

  @override
  String get pulseFilterHelp => 'সাহায্য ও সমাধান';

  @override
  String get pulseFilterDiy => 'DIY গাইড';

  @override
  String get pulseFilterMostVoted => 'সবচেয়ে বেশি ভোট';

  @override
  String get pulseFilterSaved => 'সংরক্ষিত';

  @override
  String get pulseEmptyTitle => 'আপনার পিট ওয়াল এখন শান্ত';

  @override
  String get pulseEmptyBody =>
      'কয়েকটি হাব ফলো করুন বা গ্যারেজে আপনার বাইক যোগ করুন, তাদের সর্বশেষ আলোচনা এখানে আসবে।';

  @override
  String get pulseExploreHubs => 'হাব ঘুরে দেখুন';

  @override
  String get pulseNoPostsYet =>
      'আপনার হাবগুলোতে এখনও কোনো আলোচনা নেই। একটি শুরু করুন!';

  @override
  String get pulseNoMatches => 'এই ফিল্টারে এখনও কোনো পোস্ট নেই।';

  @override
  String get pulseNoSaved =>
      'যেকোনো পোস্টের বুকমার্কে ট্যাপ করে এখানে সংরক্ষণ করুন।';

  @override
  String get savePost => 'পোস্ট সংরক্ষণ করুন';

  @override
  String get unsavePost => 'সংরক্ষিত থেকে সরান';

  @override
  String get searchForumsHint => 'ফোরাম, ব্র্যান্ড, রাইডার খুঁজুন';

  @override
  String get startDiscussion => 'আলোচনা শুরু করুন';

  @override
  String get startDiscussionPickForum => 'এটি কোথায় পোস্ট করবেন?';

  @override
  String get createRiderClub => 'ক্লাব তৈরি করুন';

  @override
  String get yourGarageHubs => 'আপনার গ্যারেজ';

  @override
  String get garageHubEmpty =>
      'মালিকদের সমস্যা সমাধান ও টিউনিং আলোচনায় যোগ দিতে গ্যারেজে আপনার বাইক যোগ করুন।';

  @override
  String get openGarage => 'গ্যারেজ খুলুন';

  @override
  String get askOwners => 'মালিকদের জিজ্ঞেস করুন';

  @override
  String get browseModelBoard => 'বোর্ড দেখুন';

  @override
  String forumThreadsCount(int count) {
    return '$countটি থ্রেড';
  }

  @override
  String get brandPaddocks => 'ব্র্যান্ড প্যাডক';

  @override
  String get openPaddock => 'প্যাডক খুলুন';

  @override
  String forumMembers(int count) {
    return '$count জন রাইডার';
  }

  @override
  String get topicBoards => 'টপিক বোর্ড';

  @override
  String get communityClubs => 'রাইডার ক্লাব';

  @override
  String get clubMaintainerBadge => 'রক্ষণাবেক্ষণকারী';

  @override
  String get boardWrenchBench => 'রেঞ্চ বেঞ্চ';

  @override
  String get boardWrenchBenchBlurb => 'রক্ষণাবেক্ষণ, সার্ভিসিং, নিজে মেরামত';

  @override
  String get boardSparkPlug => 'স্পার্ক প্লাগ কর্নার';

  @override
  String get boardSparkPlugBlurb => 'ইলেকট্রিক্যাল, ব্যাটারি, ECU টিউনিং';

  @override
  String get boardApexLab => 'এপেক্স ল্যাব';

  @override
  String get boardApexLabBlurb => 'রাইডিং দক্ষতা, ট্র্যাক ডে, কর্নারিং';

  @override
  String get boardTwoStroke => 'টু-স্ট্রোক স্মোক';

  @override
  String get boardTwoStrokeBlurb => 'ক্লাসিক টু-স্ট্রোক, কার্বুরেটর, প্রিমিক্স';

  @override
  String get boardEngineRebuild => 'ইঞ্জিন রিবিল্ড';

  @override
  String get boardEngineRebuildBlurb => 'টপ এন্ড, বটম এন্ড, মেশিনিং';

  @override
  String get boardOilReviews => 'অয়েল রিভিউ';

  @override
  String get boardOilReviewsBlurb => 'ইঞ্জিন অয়েল, গ্রেড, পরিবর্তনের ব্যবধান';

  @override
  String get boardDirtTrails => 'ডার্ট ও ট্রেইল';

  @override
  String get boardDirtTrailsBlurb => 'অফ-রোড বাইক ও ট্রেইল রাইডিং';

  @override
  String get boardMileageLab => 'মাইলেজ ল্যাব';

  @override
  String get boardMileageLabBlurb => 'জ্বালানি সাশ্রয়ের টিপস ও আসল হিসাব';

  @override
  String openBrandForumNamed(String brand) {
    return '\"$brand\" ব্র্যান্ড ফোরাম খুলুন';
  }

  @override
  String get forumPostTypeLabel => 'পোস্টের ধরন';

  @override
  String get forumPostTypeTroubleshoot => 'সমস্যা সমাধান';

  @override
  String get forumPostTypeDiyGuide => 'DIY গাইড';

  @override
  String get forumPostTypeGearReview => 'গিয়ার রিভিউ';

  @override
  String get forumPostTypeGeneral => 'সাধারণ';

  @override
  String get forumTagSolved => 'সমাধান হয়েছে';

  @override
  String get forumTagHelpNeeded => 'সাহায্য দরকার';

  @override
  String get forumTagGuide => 'গাইড';

  @override
  String get forumTagGear => 'গিয়ার';

  @override
  String get forumAttachMyBike => 'এই পোস্টে আমার বাইক দেখান';

  @override
  String get forumNoBikeToAttach =>
      'আপনার পোস্টে দেখাতে গ্যারেজে একটি বাইক যোগ করুন।';

  @override
  String get forumAttachmentRide => 'রাইডের সারাংশ';

  @override
  String get forumAttachmentMaintenance => 'রক্ষণাবেক্ষণ লগ';

  @override
  String get forumRemoveAttachment => 'সংযুক্তি সরান';

  @override
  String attachmentSharedFrom(String name) {
    return '$name-এর নিজের লগ থেকে শেয়ার করা।';
  }

  @override
  String get forumAcceptedSolution => 'গৃহীত সমাধান';

  @override
  String get forumAcceptSolution => 'সমাধান হিসেবে গ্রহণ করুন';

  @override
  String get forumUnacceptSolution => 'সমাধান থেকে সরান';

  @override
  String get forumMarkSolved => 'সমাধান হয়েছে চিহ্নিত করুন';

  @override
  String get forumReopen => 'আবার খুলুন';

  @override
  String forumCouldNotUpdateSolution(Object e) {
    return 'সমাধান আপডেট করা যায়নি: $e';
  }

  @override
  String get shareToForum => 'ফোরামে শেয়ার করুন';

  @override
  String get shareToForumPick => 'কোন ফোরামে শেয়ার করবেন?';

  @override
  String rideAttachmentTitle(String date) {
    return '$date-এর রাইড';
  }

  @override
  String forumAddPhotos(int count, int max) {
    return 'ছবি যোগ করুন ($count/$max)';
  }

  @override
  String paddockPosts(int count) {
    return '$countটি পোস্ট';
  }

  @override
  String forumPhotoUploadFailed(String e) {
    return 'ছবি আপলোড করা যায়নি: $e';
  }

  @override
  String get groupRideRealtimeLive => 'লাইভ';

  @override
  String get groupRideRealtimeDelayed => 'বিলম্বিত';

  @override
  String get chatTyping => 'টাইপ করছে…';

  @override
  String get signOutFailed => 'সাইন আউট করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get deleteAccountFailed =>
      'আপনার অ্যাকাউন্ট মুছে ফেলা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get deleteAccountOffline =>
      'ইন্টারনেট সংযোগ নেই। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get reauthRequiredTitle => 'নিশ্চিত করুন এটি আপনিই';

  @override
  String get reauthRequiredBody =>
      'নিরাপত্তার জন্য অ্যাকাউন্ট মুছতে আপনার পাসওয়ার্ড নিশ্চিত করুন।';

  @override
  String get reauthWrongPassword => 'পাসওয়ার্ডটি সঠিক নয়।';

  @override
  String get reauthFailed =>
      'আপনার পরিচয় নিশ্চিত করা যায়নি। অ্যাকাউন্ট মুছে ফেলা হয়নি।';

  @override
  String get navGarageLabel => 'গ্যারেজ';

  @override
  String get archiveAlsoDelete => 'এগুলোও মুছুন (ঐচ্ছিক):';

  @override
  String get archiveOptSharedRides => 'শেয়ার করা রাইড';

  @override
  String get archiveOptSharedRidesHint =>
      'কমিউনিটি ফিড থেকে এই বাইকের রাইড সরিয়ে দেয়।';

  @override
  String get archiveOptMiles => 'হিসাব করা দূরত্ব';

  @override
  String get archiveOptMilesHint =>
      'এই বাইকের দূরত্ব ও রাইড গণনা শূন্য করে। রাইডগুলো আপনার ইতিহাসে থাকবে।';

  @override
  String get archiveOptServiceLogs => 'সার্ভিস লগ';

  @override
  String get archiveOptServiceLogsHint =>
      'এই বাইকের রক্ষণাবেক্ষণের ইতিহাস মুছে দেয়।';

  @override
  String get archiveOptPhotos => 'ছবি';

  @override
  String get archiveOptPhotosHint => 'বাইকের ছবি ও সার্ভিসের রসিদ সরিয়ে দেয়।';

  @override
  String get archiveBikeConfirm => 'বাইক আর্কাইভ করুন';

  @override
  String get bikeArchivedTitle => 'বাইক আর্কাইভ হয়েছে';

  @override
  String bikeArchivedBody(String bike, String date) {
    return '$bike আর্কাইভ হয়েছে। তিন মাস পরে, $date তারিখে এটি স্থায়ীভাবে মুছে যাবে। তার আগে আপনি এটি ফিরিয়ে আনতে, এর তথ্যের একটি কপি ডাউনলোড করতে, বা এখনই মুছে ফেলতে পারবেন।';
  }

  @override
  String get downloadLocalCopy => 'একটি লোকাল কপি ডাউনলোড করুন';

  @override
  String get deleteNowAction => 'এখনই মুছুন';

  @override
  String archivedPurgesIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days দিনে',
      one: '1 দিনে',
      zero: 'এক দিনেরও কম সময়ে',
    );
    return '$_temp0 মুছে যাবে';
  }

  @override
  String couldNotExportBike(Object error) {
    return 'এক্সপোর্ট করা যায়নি: $error';
  }

  @override
  String get couldNotArchiveSharedRides =>
      'শেয়ার করা রাইড সরানো যায়নি, তাই বাইকটি আর্কাইভ হয়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

  @override
  String get badgeRarityCommon => 'সাধারণ';

  @override
  String get badgeRarityUncommon => 'কিছুটা বিরল';

  @override
  String get badgeRarityRare => 'দুর্লভ';

  @override
  String get badgeRarityEpic => 'এপিক';

  @override
  String get badgeRarityLegendary => 'কিংবদন্তি';

  @override
  String badgeOwnedByPercent(String percent) {
    return '$percent রাইডারের কাছে এই ব্যাজ আছে';
  }

  @override
  String get badgeOwnershipUnknown =>
      'এই মুহূর্তে বিরলতার তথ্য পাওয়া যাচ্ছে না';

  @override
  String get badgeRarityLabel => 'বিরলতা';

  @override
  String get badgeHowToEarn => 'কীভাবে পাবেন';

  @override
  String badgeEarnedOn(String date) {
    return 'অর্জিত $date';
  }

  @override
  String get badgeEarnedStatus => 'অর্জিত';

  @override
  String get badgeLockedStatus => 'লক করা';

  @override
  String badgeProgressFraction(String progress, String target, String unit) {
    return '$target $unit-এর মধ্যে $progress';
  }

  @override
  String badgeProgressToGo(String remaining, String unit) {
    return 'আরও $remaining $unit বাকি';
  }

  @override
  String get badgeShareAction => 'শেয়ার করুন';

  @override
  String badgeShareText(String badge) {
    return 'আমি ThrottleIQ-তে $badge ব্যাজ অর্জন করেছি।';
  }

  @override
  String badgeShareTextRarity(String badge, String rarity, String percent) {
    return 'আমি ThrottleIQ-তে $badge ব্যাজ অর্জন করেছি। $rarity: $percent রাইডারের কাছে এটি আছে।';
  }

  @override
  String get badgeViewDetails => 'বিস্তারিত দেখতে ট্যাপ করুন';

  @override
  String tourStepCounter(int current, int total) {
    return 'ধাপ $current / $total';
  }

  @override
  String get tourBack => 'পেছনে';

  @override
  String get tourNext => 'পরবর্তী';

  @override
  String get tourFinish => 'রাইড শুরু করুন';

  @override
  String get tourShowMeLive => 'স্ক্রিনটি দেখান';

  @override
  String get tourRecordTitle => 'তৈরি? চলুন রাইডে';

  @override
  String get tourRecordSubtitle =>
      'রেকর্ড ট্যাবই মূল জায়গা: বাইক বাছুন, কীভাবে চালাবেন ঠিক করুন, আর বেরিয়ে পড়ুন।';

  @override
  String get tourRecordBikeTitle => 'আপনার সক্রিয় বাইক';

  @override
  String get tourRecordBikeBody =>
      'ওপরের বাইক কার্ডের বাইকেই এই রাইড যোগ হবে। বাইক বদলাতে কার্ডে ট্যাপ করুন।';

  @override
  String get tourRecordModeTitle => 'একা বা দলে';

  @override
  String get tourRecordModeBody =>
      'একা চালান, অথবা গ্রুপ রাইড শুরু করে বন্ধুদের আমন্ত্রণ জানান বা জয়েন কোড শেয়ার করুন।';

  @override
  String get tourRecordStartTitle => 'শুরু করতে চেপে ধরুন বা স্লাইড করুন';

  @override
  String get tourRecordStartBody =>
      'স্টার্ট রিং চেপে ধরুন (বক্সি স্টাইলে বারটি স্লাইড করুন), যাতে ভুল ছোঁয়ায় রাইড শুরু না হয়।';

  @override
  String get tourCockpitTitle => 'আপনার লাইভ ককপিট';

  @override
  String get tourCockpitSubtitle =>
      'শুরু করলেই এক নজরে পড়ার মতো ককপিট পুরো স্ক্রিন জুড়ে দেখায়।';

  @override
  String get tourCockpitLocation => 'রেকর্ড › রাইড শুরু';

  @override
  String get tourCockpitGaugesTitle => 'এক নজরে গতি';

  @override
  String get tourCockpitGaugesBody =>
      'বড় করে লাইভ গতি, দূরত্ব ও গড় গতি, হ্যান্ডেলবারে লাগানো ফোন থেকেও পড়া যায়। যেকোনো সময় থামান, আবার চালু করুন বা শেষ করুন।';

  @override
  String get tourCockpitShareTitle => 'লাইভ লোকেশন শেয়ার করুন';

  @override
  String get tourCockpitShareBody =>
      'পরিবারকে একটি লাইভ লিংক পাঠান, যাতে তারা আপনার রাইড দেখতে পারে। রাইড শেষ হলে এটি বন্ধ হয়ে যায়।';

  @override
  String get tourCockpitSafetyTitle => 'রাইড সতর্কতা ও দুর্ঘটনা যাচাই';

  @override
  String get tourCockpitSafetyBody =>
      'অতিরিক্ত গতি, হঠাৎ ব্রেক ও ক্লান্তি নিয়ে সতর্কবার্তা পান। দুর্ঘটনা সন্দেহ হলে \"আমি ঠিক আছি\" ট্যাপ করুন, নইলে আপনার জরুরি যোগাযোগদের জানানো হবে।';

  @override
  String get tourCockpitJamTitle => 'জ্যাম চিহ্নিত করুন';

  @override
  String get tourCockpitJamBody =>
      'আটকে গেলে \"আমি জ্যামে আছি\" আর ছাড়লে \"জ্যাম ছেড়েছে\" ট্যাপ করুন; এতে জ্যাম শনাক্তকরণ আরও ভালো হয়।';

  @override
  String get tourAutoTitle => 'অটো ট্র্যাকিং';

  @override
  String get tourAutoSubtitle =>
      'স্টার্ট চাপতে ভুলে গেছেন? ThrottleIQ নিজেই আপনার রাইড বুঝে লগ করতে পারে।';

  @override
  String get tourAutoLocation => 'গ্যারেজ › সেটিংস';

  @override
  String get tourAutoDetectTitle => 'একবার চালু করুন';

  @override
  String get tourAutoDetectBody =>
      'সেটিংসে অটো ট্র্যাকিং চালু করুন, তাহলে রওনা দিলেই নিজে থেকে রেকর্ডিং শুরু হবে।';

  @override
  String get tourAutoFilterTitle => 'রাইড নয় এমন যাত্রা বাদ';

  @override
  String get tourAutoFilterBody =>
      'হাঁটা, বাস ও গাড়ির যাত্রা বাদ পড়ে, শুধু মোটরসাইকেল রাইড রাখা হয়।';

  @override
  String get tourAutoHistoryTitle => 'শনাক্তকরণ দেখুন';

  @override
  String get tourAutoHistoryBody =>
      'অটো ট্র্যাকিং টাইল থেকে শনাক্তকরণের ইতিহাস খুলে দেখুন কী রেকর্ড হয়েছে এবং কেন।';

  @override
  String get tourRidesTitle => 'সংখ্যায় আপনার রাইডিং';

  @override
  String get tourRidesSubtitle =>
      'রাইড ট্যাব প্রতিটি যাত্রাকে ট্রেন্ড, স্কোর ও ব্যাজে রূপ দেয়।';

  @override
  String get tourRidesScoreTitle => 'স্কোর ও রাইডার র‍্যাংক';

  @override
  String get tourRidesScoreBody =>
      'যত বেশি চালাবেন, আপনার জার্নি স্কোর ও র‍্যাংক তত বাড়বে।';

  @override
  String get tourRidesChartsTitle => 'ট্রেন্ড চার্ট';

  @override
  String get tourRidesChartsBody =>
      'সময়ের সাথে দূরত্ব ও গতি। সব রাইড খুলে সাজিয়ে দেখুন, যেকোনো রাইডের সারাংশও পাবেন।';

  @override
  String get tourRidesBadgesTitle => 'ব্যাজ';

  @override
  String get tourRidesBadgesBody =>
      'মাইলফলক ছুঁয়ে ব্যাজ অর্জন করুন। কোনো ব্যাজ আনলক করতে কী লাগে দেখতে সেটিতে ট্যাপ করুন।';

  @override
  String get tourGarageTitle => 'আপনার গ্যারেজ';

  @override
  String get tourGarageSubtitle =>
      'আপনার প্রতিটি বাইক, প্রত্যেকটির আলাদা রাইড, দূরত্ব ও সার্ভিস ইতিহাসসহ।';

  @override
  String get tourGarageActiveTitle => 'সক্রিয় বাইক বেছে নিন';

  @override
  String get tourGarageActiveBody =>
      'নতুন রাইড ও কিলোমিটার সক্রিয় বাইকে যোগ হয়। যেকোনো সময় বদলাতে পারবেন।';

  @override
  String get tourGarageDetailTitle => 'বাইকের বিস্তারিত';

  @override
  String get tourGarageDetailBody =>
      'ছবি যোগ করতে, স্পেসিফিকেশন বদলাতে ও রাইড দেখতে বাইকে ট্যাপ করুন।';

  @override
  String get tourGarageArchiveTitle => 'পুরোনো বাইক আর্কাইভ করুন';

  @override
  String get tourGarageArchiveBody =>
      'বাইক বিক্রি করেছেন? আর্কাইভ করুন। এটি 90 দিন আর্কাইভ করা বাইকের তালিকায় থাকে, এর মধ্যে আবার ফিরিয়ে আনতে পারবেন।';

  @override
  String get tourMaintenanceTitle => 'সময়মতো রক্ষণাবেক্ষণ';

  @override
  String get tourMaintenanceSubtitle =>
      'আপনি আসলে যত কিলোমিটার চালান, তার ভিত্তিতে সার্ভিস রিমাইন্ডার।';

  @override
  String get tourMaintenanceLocation => 'গ্যারেজ › রক্ষণাবেক্ষণ';

  @override
  String get tourMaintenanceDueTitle => 'কী বাকি, এক নজরে';

  @override
  String get tourMaintenanceDueBody =>
      'ইঞ্জিন অয়েল, চেইন, ব্রেকসহ সবকিছুর পরের সার্ভিস পর্যন্ত রঙে চিহ্নিত কাউন্টডাউন।';

  @override
  String get tourMaintenanceOdoTitle => 'ওডোমিটার মিলিয়ে নিন';

  @override
  String get tourMaintenanceOdoBody =>
      'মাঝে মাঝে বাইকের আসল ওডোমিটার রিডিং দিন, যাতে প্রতিটি কাউন্টডাউন ঠিক থাকে।';

  @override
  String get tourMaintenanceLogTitle => 'সার্ভিস লগ করুন';

  @override
  String get tourMaintenanceLogBody =>
      'কী করা হলো লিখে রাখুন, কাউন্টডাউন আবার শুরু হবে।';

  @override
  String get tourPlacesTitle => 'রাইডারদের জায়গা';

  @override
  String get tourPlacesSubtitle =>
      'কাছের পেট্রোল পাম্প, ওয়ার্কশপ, পার্টস ও আড্ডার জায়গা, ম্যাপে বা তালিকায়।';

  @override
  String get tourPlacesMapTitle => 'ম্যাপ ও ফিল্টার';

  @override
  String get tourPlacesMapBody =>
      'ধরন অনুযায়ী ফিল্টার করুন, ম্যাপ ও তালিকার মধ্যে বদলান, আর যেকোনো জায়গার দিকনির্দেশনা নিন।';

  @override
  String get tourPlacesRoutesTitle => 'রুট ও সংরক্ষিত জায়গা';

  @override
  String get tourPlacesRoutesBody =>
      'রাইডকে রুট হিসেবে সংরক্ষণ করুন, অন্য রাইডারদের রুট খুঁজুন, আর প্রিয় জায়গাগুলো রেখে দিন।';

  @override
  String get tourPlacesAddTitle => 'জায়গা যোগ করুন';

  @override
  String get tourPlacesAddBody =>
      'ভালো মেকানিক চেনেন? যোগ করুন, আর জায়গাগুলোকে রেটিং দিয়ে অন্য রাইডারদের সাহায্য করুন।';

  @override
  String get tourSocialTitle => 'একসাথে রাইড';

  @override
  String get tourSocialSubtitle =>
      'রাইড শেয়ার করুন, রাইডার খুঁজুন, বাইক নিয়ে আলাপ করুন, সব এক জায়গায়।';

  @override
  String get tourSocialFeedTitle => 'রাইড ফিড ও মানুষ';

  @override
  String get tourSocialFeedBody =>
      'শেয়ার করা রাইড দেখুন, ফলো করার মতো রাইডার খুঁজুন, আর সরাসরি মেসেজ পাঠান।';

  @override
  String get tourSocialForumsTitle => 'ফোরাম';

  @override
  String get tourSocialForumsBody =>
      'মডিফিকেশন, সমস্যা ও মিটআপ নিয়ে বাইক মডেলভিত্তিক ফোরাম।';

  @override
  String get tourSocialGroupTitle => 'গ্রুপ রাইড';

  @override
  String get tourSocialGroupBody =>
      'লাইভ ম্যাপে দল বেঁধে চালান, পুরো দলের সাথে পুশ-টু-টক।';

  @override
  String get tourProfileTitle => 'আপনার রাইডার প্রোফাইল';

  @override
  String get tourProfileSubtitle =>
      'আপনার পাবলিক পেজ: পরিসংখ্যান, গ্যারেজ, ফলোয়ার ও আপনি যাদের ফলো করেন।';

  @override
  String get tourProfileLocation => 'গ্যারেজ › প্রোফাইল দেখুন';

  @override
  String get tourProfileQrTitle => 'QR দিয়ে ফলো';

  @override
  String get tourProfileQrBody =>
      'আপনার QR কোড দেখান, যাতে রাইডিং সঙ্গী এক স্ক্যানেই আপনাকে ফলো করতে পারে, অথবা তাদেরটা স্ক্যান করুন।';

  @override
  String get tourProfilePrivacyTitle => 'কে কী দেখবে, আপনিই ঠিক করুন';

  @override
  String get tourProfilePrivacyBody =>
      'প্রোফাইল এডিট থেকে ঠিক করুন কে আপনার প্রোফাইল ও বাইক দেখতে পারবে।';

  @override
  String get tourProfileSafeQrTitle => 'SafeQR মেডিকেল কার্ড';

  @override
  String get tourProfileSafeQrBody =>
      'সেটিংসে রক্তের গ্রুপ ও জরুরি যোগাযোগসহ একটি স্ক্যানযোগ্য কার্ড তৈরি করুন, যা উদ্ধারকারীদের কাজে আসবে।';

  @override
  String get fuelTitle => 'জ্বালানি';

  @override
  String get fuelLogTitle => 'জ্বালানির লগ';

  @override
  String get fuelAddTitle => 'ফিল-আপ লগ করুন';

  @override
  String get fuelEditTitle => 'ফিল-আপ এডিট করুন';

  @override
  String get fuelLitersLabel => 'লিটার *';

  @override
  String get fuelTotalCostLabel => 'মোট দাম';

  @override
  String get fuelPricePerLiterLabel => 'প্রতি লিটারের দাম';

  @override
  String get fuelPriceHint =>
      'মোট দাম অথবা প্রতি লিটারের দাম দিন; অন্যটি নিজে থেকে হিসাব হবে।';

  @override
  String get fuelFullTankLabel => 'ট্যাংক ফুল করা হয়েছে';

  @override
  String get fuelFullTankHint =>
      'km/L হিসাবের জন্য দরকার। আংশিক ভরলে বন্ধ রাখুন।';

  @override
  String get fuelStationLabel => 'পাম্প (ঐচ্ছিক)';

  @override
  String get fuelSave => 'ফিল-আপ সেভ করুন';

  @override
  String get fuelSaved => 'ফিল-আপ সেভ হয়েছে';

  @override
  String get fuelUpdated => 'ফিল-আপ আপডেট হয়েছে';

  @override
  String get fuelSaveFailed => 'ফিল-আপ সেভ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get fuelDeleteTitle => 'এই ফিল-আপটি মুছবেন?';

  @override
  String get fuelDeleteBody => 'এটি এই ফোন ও আপনার ব্যাকআপ থেকে মুছে যাবে।';

  @override
  String get fuelDeleted => 'ফিল-আপ মুছে ফেলা হয়েছে';

  @override
  String get fuelMoneyRequired => 'মোট দাম অথবা প্রতি লিটারের দাম দিন';

  @override
  String get fuelOdometerBelowEarlier =>
      'আগের একটি ফিল-আপের ওডোমিটারের চেয়ে কম';

  @override
  String get fuelOdometerAboveLater =>
      'পরের একটি ফিল-আপের ওডোমিটারের চেয়ে বেশি';

  @override
  String get fuelEmptyTitle => 'এখনো কোনো ফিল-আপ লগ করা হয়নি';

  @override
  String get fuelEmptyBody =>
      'প্রতিবার তেল নেওয়ার পর লগ করুন, আসল km/L ও জ্বালানি খরচ দেখতে পাবেন।';

  @override
  String get fuelPartial => 'আংশিক';

  @override
  String get fuelAvgEfficiency => 'গড় km/L';

  @override
  String get fuelLastEfficiency => 'শেষ km/L';

  @override
  String get fuelTotalSpent => 'জ্বালানি খরচ';

  @override
  String get fuelTotalLiters => 'লিটার';

  @override
  String get fuelCostPerKm => 'প্রতি কিমি খরচ';

  @override
  String get fuelAvgPrice => 'গড় দাম/লিটার';

  @override
  String fuelFillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি ফিল-আপ',
      one: '1টি ফিল-আপ',
    );
    return '$_temp0';
  }

  @override
  String get fuelNeedTwoFull => 'দুইবার ফুল ট্যাংক করার পর km/L দেখা যাবে।';

  @override
  String get fuelCardNone => 'এখনো কোনো ফিল-আপ নেই। km/L দেখতে একটি লগ করুন।';

  @override
  String fuelCardSummary(String efficiency, String date) {
    return 'গড় $efficiency km/L · শেষ ফিল $date';
  }

  @override
  String fuelCardLastOnly(String date) {
    return 'শেষ ফিল $date';
  }

  @override
  String get archiveOptFuelLogs => 'জ্বালানির লগ';

  @override
  String get archiveOptFuelLogsHint => 'এই বাইকের ফিল-আপের ইতিহাস মুছে দেয়।';

  @override
  String get chartFuelSpend => 'মাসিক জ্বালানি খরচ';

  @override
  String get chartFuelEfficiency => 'জ্বালানি দক্ষতা';

  @override
  String get chartFuelCostPerKm => 'প্রতি কিমি জ্বালানি খরচ';

  @override
  String get chartFuelLiters => 'মাসিক লিটার';

  @override
  String get fuelChartEmptyHint => 'এটি দেখতে জ্বালানির ফিল-আপ লগ করুন';

  @override
  String get analyticsColMonth => 'মাস';

  @override
  String get analyticsColFillUps => 'ফিল-আপ';

  @override
  String get analyticsColDistance => 'দূরত্ব';

  @override
  String insightPeakMonth(String value, String month) {
    return 'সবচেয়ে বেশি ছিল $month-এ $value।';
  }

  @override
  String insightFuelAverage(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি ফুল-ট্যাংক পর্বে',
      one: '1টি ফুল-ট্যাংক পর্বে',
    );
    return 'গড় $value, $_temp0।';
  }

  @override
  String get insightFuelNeedFullFills =>
      'এটি মাপতে দুইবার ফুল ট্যাংকের ফিল-আপ লগ করুন।';
}
