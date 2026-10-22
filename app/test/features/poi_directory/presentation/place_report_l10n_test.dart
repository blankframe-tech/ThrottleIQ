import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/presentation/place_report_l10n.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final l10n = lookupAppLocalizations(const Locale('en'));
  final reported = DateTime(2026, 10, 17, 14, 14);

  PlaceEntity checkpoint({DateTime? expiresAt}) => PlaceEntity(
        id: 'p',
        name: 'Cop checkpoint',
        category: PlaceCategory.police,
        latitude: 23.8,
        longitude: 90.4,
        geohash: 'wh0r',
        address: '',
        createdBy: 'u',
        createdAt: reported,
        expiresAt: expiresAt,
      );

  test('permanent places get no report label', () {
    expect(placeReportLabel(checkpoint(), l10n, now: reported), isNull);
  });

  test('same-day report shows the time and the hours left', () {
    final place =
        checkpoint(expiresAt: reported.add(const Duration(hours: 24)));
    expect(
      // intl's jm puts a narrow no-break space before "PM".
      placeReportLabel(place, l10n,
              now: reported.add(const Duration(minutes: 30)))
          ?.replaceAll('\u202f', ' '),
      'Reported 2:14 PM · expires in 24 h',
    );
  });

  test('a report from yesterday carries its date; under an hour reads 1 h', () {
    final place =
        checkpoint(expiresAt: reported.add(const Duration(hours: 24)));
    expect(
      placeReportLabel(place, l10n,
          now: reported.add(const Duration(hours: 23, minutes: 30))),
      'Reported 17 Oct, 2:14 PM · expires in 1 h',
    );
  });

  test('an expired report says so', () {
    final place =
        checkpoint(expiresAt: reported.add(const Duration(hours: 24)));
    expect(
      placeReportLabel(place, l10n,
          now: reported.add(const Duration(hours: 25))),
      'Reported 17 Oct, 2:14 PM · expired',
    );
  });
}
