double? parseLocalizedNumber(String value) {
  const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  var englishVal = value.replaceAll(',', '.');
  englishVal = englishVal.replaceAll(RegExp(r'[^\d\.\-]'), '');
  for (int i = 0; i < 10; i++) {
    englishVal = englishVal.replaceAll(banglaDigits[i], i.toString());
  }
  return double.tryParse(englishVal);
}

int? parseLocalizedInt(String value) {
  const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  var englishVal = value.replaceAll(RegExp(r'[^\d\-]'), '');
  for (int i = 0; i < 10; i++) {
    englishVal = englishVal.replaceAll(banglaDigits[i], i.toString());
  }
  return int.tryParse(englishVal);
}
