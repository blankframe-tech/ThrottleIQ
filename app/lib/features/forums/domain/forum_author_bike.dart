import '../../garage/domain/entities/bike_entity.dart';
import 'entities/forum_post_entity.dart' show kAuthorBikeMaxLength;

/// "12,400 km" — whole kilometres, thousands grouped. Western digits in
/// every locale (core/i18n/numeric_locale.dart).
String formatOdometerKm(double km) {
  final whole = km.isFinite && km > 0 ? km.round() : 0;
  final digits = whole.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '$grouped km';
}

/// The byline badge a post carries for [bike]: "Yamaha MT-15 (2023) ·
/// 12,400 km", or just the name when the bike has no mileage yet. Capped at
/// [kAuthorBikeMaxLength] like the stored field.
String authorBikeLabel(BikeEntity bike) {
  final km = bike.currentOdometerKm;
  final label = km > 0 ? '${bike.displayName} · ${formatOdometerKm(km)}' : bike.displayName;
  return label.length <= kAuthorBikeMaxLength
      ? label
      : label.substring(0, kAuthorBikeMaxLength);
}
