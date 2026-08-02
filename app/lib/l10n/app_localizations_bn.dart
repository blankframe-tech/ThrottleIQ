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
  String get themeCarbonLabel => 'কার্বন মোনো';

  @override
  String get themeCarbonDescription => 'গাঢ়, ঝকঝকে, মিটারের মতো';

  @override
  String get themeEditorialLabel => 'এডিটোরিয়াল';

  @override
  String get themeEditorialDescription => 'হালকা, কাগজের মতো নরম';

  @override
  String get appMarkTitle => 'অ্যাপের লোগো';

  @override
  String get appMarkDarkDescription =>
      'গাঢ় লোগোটা — স্প্ল্যাশ আর সাইন-ইন স্ক্রিনে এটাই দেখবেন।';

  @override
  String get appMarkLightDescription =>
      'হালকা লোগোটা — স্প্ল্যাশ আর সাইন-ইন স্ক্রিনে এটাই দেখবেন।';

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
      'দুর্ঘটনা ধরা পড়লে আর আপনি 60 সেকেন্ডের মধ্যে সাড়া না দিলে এদেরকে জানিয়ে দেওয়া হবে।';

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
}
