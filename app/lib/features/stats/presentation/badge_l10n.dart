import '../../../core/utils/badges.dart';
import '../../../l10n/app_localizations.dart';

/// Badge text in the rider's language.
///
/// `core/utils/badges.dart` keeps the English copy: badge and rung **ids are
/// persisted** (`users/{uid}/earnedBadges`) and the domain stays free of
/// Flutter/l10n. What is *displayed* goes through here, keyed by those stable
/// ids. An id with no entry (a rung added without a key) falls back to its
/// English name rather than failing.
extension BadgeFamilyL10n on BadgeFamily {
  String localizedName(AppLocalizations l) => switch (id) {
        'first' => l.badgeFamFirstName,
        'rides' => l.badgeFamRidesName,
        'distance' => l.badgeFamDistanceName,
        'long_ride' => l.badgeFamLongRideName,
        'saddle_time' => l.badgeFamSaddleTimeName,
        'speed' => l.badgeFamSpeedName,
        'night' => l.badgeFamNightName,
        'early' => l.badgeFamEarlyName,
        'streak' => l.badgeFamStreakName,
        'smooth' => l.badgeFamSmoothName,
        _ => name,
      };

  String localizedAbout(AppLocalizations l) => switch (id) {
        'first' => l.badgeFamFirstAbout,
        'rides' => l.badgeFamRidesAbout,
        'distance' => l.badgeFamDistanceAbout,
        'long_ride' => l.badgeFamLongRideAbout,
        'saddle_time' => l.badgeFamSaddleTimeAbout,
        'speed' => l.badgeFamSpeedAbout,
        'night' => l.badgeFamNightAbout,
        'early' => l.badgeFamEarlyAbout,
        'streak' => l.badgeFamStreakAbout,
        'smooth' => l.badgeFamSmoothAbout,
        _ => about,
      };

  String localizedUnit(AppLocalizations l) => switch (unit) {
        'rides' => l.badgeUnitRides,
        'km' => l.badgeUnitKm,
        'h' => l.badgeUnitHours,
        'km/h' => l.badgeUnitKmh,
        'days' => l.badgeUnitDays,
        'pts' => l.badgeUnitPts,
        _ => unit,
      };

  /// [requirementFor] in the rider's language.
  String localizedRequirementFor(AppLocalizations l, num threshold) {
    final n = formatBadgeValue(threshold);
    return switch (id) {
      'first' => l.badgeFamFirstReq,
      'rides' => l.badgeFamRidesReq(n),
      'distance' => l.badgeFamDistanceReq(n),
      'long_ride' => l.badgeFamLongRideReq(n),
      'saddle_time' => l.badgeFamSaddleTimeReq(n),
      'speed' => l.badgeFamSpeedReq(n),
      'night' => l.badgeFamNightReq(n),
      'early' => l.badgeFamEarlyReq(n),
      'streak' => l.badgeFamStreakReq(n),
      'smooth' => l.badgeFamSmoothReq(n),
      _ => requirementFor(threshold),
    };
  }
}

String _rungName(AppLocalizations l, String id, String fallback) =>
    switch (id) {
      'first_ride' => l.badgeRungFirstRide,
      'rides_10' => l.badgeRungRides10,
      'rides_25' => l.badgeRungRides25,
      'rides_50' => l.badgeRungRides50,
      'rides_100' => l.badgeRungRides100,
      'rides_250' => l.badgeRungRides250,
      'km_100' => l.badgeRungKm100,
      'km_500' => l.badgeRungKm500,
      'km_1000' => l.badgeRungKm1000,
      'km_2500' => l.badgeRungKm2500,
      'km_5000' => l.badgeRungKm5000,
      'long_ride_50' => l.badgeRungLongRide50,
      'long_ride_100' => l.badgeRungLongRide100,
      'long_ride_200' => l.badgeRungLongRide200,
      'long_ride_400' => l.badgeRungLongRide400,
      'long_ride_800' => l.badgeRungLongRide800,
      'saddle_1h' => l.badgeRungSaddle1h,
      'saddle_2h' => l.badgeRungSaddle2h,
      'saddle_4h' => l.badgeRungSaddle4h,
      'saddle_8h' => l.badgeRungSaddle8h,
      'ton_up' => l.badgeRungTonUp,
      'speed_140' => l.badgeRungSpeed140,
      'speed_demon' => l.badgeRungSpeedDemon,
      'night_1' => l.badgeRungNight1,
      'night_5' => l.badgeRungNight5,
      'night_25' => l.badgeRungNight25,
      'night_50' => l.badgeRungNight50,
      'early_1' => l.badgeRungEarly1,
      'early_5' => l.badgeRungEarly5,
      'early_25' => l.badgeRungEarly25,
      'streak_3' => l.badgeRungStreak3,
      'streak_7' => l.badgeRungStreak7,
      'streak_14' => l.badgeRungStreak14,
      'streak_30' => l.badgeRungStreak30,
      'smooth_80' => l.badgeRungSmooth80,
      'smooth_operator' => l.badgeRungSmoothOperator,
      'smooth_95' => l.badgeRungSmooth95,
      'smooth_98' => l.badgeRungSmooth98,
      _ => fallback,
    };

extension BadgeTierSpecL10n on BadgeTierSpec {
  String localizedName(AppLocalizations l) => _rungName(l, id, name);
}

extension BadgeDefL10n on BadgeDef {
  String localizedName(AppLocalizations l) => _rungName(l, id, name);
}

extension BadgeTierL10n on BadgeTier {
  String localizedLabel(AppLocalizations l) => switch (this) {
        BadgeTier.bronze => l.badgeTierBronze,
        BadgeTier.silver => l.badgeTierSilver,
        BadgeTier.gold => l.badgeTierGold,
        BadgeTier.platinum => l.badgeTierPlatinum,
        BadgeTier.diamond => l.badgeTierDiamond,
      };
}
