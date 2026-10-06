import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/domain/highway_radar.dart';

const _lat = 23.7580;
const _lng = 90.3900;

PlaceEntity _place(String id, PlaceCategory category, double kmNorth) => PlaceEntity(
      id: id,
      name: id,
      category: category,
      latitude: _lat + kmNorth * 0.009,
      longitude: _lng,
      geohash: '',
      address: '',
      createdBy: 'u',
      createdAt: DateTime(2026),
    );

void main() {
  final places = [
    _place('cam-near', PlaceCategory.aiCamera, 2),
    _place('cam-far', PlaceCategory.aiCamera, 40),
    _place('cam-mid', PlaceCategory.aiCamera, 9),
    _place('cop', PlaceCategory.police, 1),
    _place('pump', PlaceCategory.fuel, 0.5),
  ];

  test('keeps only safety points within the radius, nearest first', () {
    final radar = computeHighwayRadar(places, originLat: _lat, originLng: _lng, radiusKm: 15);
    expect([for (final h in radar.cameras) h.place.id], ['cam-near', 'cam-mid']);
    expect([for (final h in radar.police) h.place.id], ['cop']);
    expect(radar.total, 3);
    expect(radar.isEmpty, isFalse);
    expect([for (final h in radar.all) h.place.id], ['cop', 'cam-near', 'cam-mid']);
    expect(radar.nearest!.place.id, 'cop');
    expect(radar.nearest!.distanceKm, closeTo(1, 0.05));
  });

  test('a wider radius picks up the far camera', () {
    final radar = computeHighwayRadar(places, originLat: _lat, originLng: _lng, radiusKm: 50);
    expect(radar.cameras.length, 3);
  });

  test('no safety points → empty radar', () {
    final radar = computeHighwayRadar(
      [_place('pump', PlaceCategory.fuel, 1)],
      originLat: _lat,
      originLng: _lng,
      radiusKm: 25,
    );
    expect(radar.isEmpty, isTrue);
    expect(radar.nearest, isNull);
    expect(radar, HighwayRadar.empty);
  });

  test('without a fix every safety point in the batch is reported, with no distance', () {
    final radar = computeHighwayRadar(places, radiusKm: 5);
    expect(radar.total, 4);
    expect(radar.nearest, isNull);
  });
}
