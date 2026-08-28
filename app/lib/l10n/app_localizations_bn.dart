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
  String get themeRetroDescription => 'সাদা-কালো টার্মিনাল, কোনো রং নেই';

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
  String get exportFailedMessage => 'এক্সপোর্ট ব্যর্থ হয়েছে';

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
}
