import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';
import 'package:throttleiq/features/forums/domain/forum_author_bike.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';

BikeEntity bike({double? odometerKm, double gpsM = 0, String model = 'MT-15', int? year}) =>
    BikeEntity(
      id: 'b',
      userId: 'u',
      brand: 'Yamaha',
      model: model,
      year: year,
      odometerKm: odometerKm,
      totalDistanceM: gpsM,
      createdAt: DateTime(2026),
    );

void main() {
  test('formatOdometerKm groups thousands with Western digits', () {
    expect(formatOdometerKm(12400.4), '12,400 km');
    expect(formatOdometerKm(999), '999 km');
    expect(formatOdometerKm(1234567), '1,234,567 km');
    expect(formatOdometerKm(-5), '0 km');
  });

  test('the byline carries the bike and its current mileage', () {
    expect(
      authorBikeLabel(bike(odometerKm: 12000, gpsM: 400000, year: 2023)),
      'Yamaha MT-15 (2023) · 12,400 km',
    );
  });

  test('a bike with no mileage yet shows just its name', () {
    expect(authorBikeLabel(bike()), 'Yamaha MT-15');
  });

  test('the byline never exceeds the stored cap', () {
    expect(authorBikeLabel(bike(model: 'X' * 200, odometerKm: 10)).length,
        kAuthorBikeMaxLength);
  });
}
