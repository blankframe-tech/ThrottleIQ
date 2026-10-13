import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/social/data/models/ride_share_model.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';

void main() {
  group('SharedRideEntity physical speed invariants', () {
    test('heals zero maxSpeedKmh to avgSpeedKmh when ride was moving', () {
      // 4.0 km in 960 seconds (16 min) = 15.0 km/h average
      final ride = SharedRideEntity(
        id: 'r1',
        userId: 'u1',
        userName: 'Rider',
        userPhotoUrl: '',
        bikeId: 'b1',
        bikeName: 'CBR',
        bikeType: '160cc',
        rideDate: DateTime(2026, 9, 9),
        distanceKm: 4.0,
        durationSeconds: 960,
        maxSpeedKmh: 0.0, // Buggy/missing max speed
        polyline: const [LatLng(23.72, 90.38), LatLng(23.74, 90.39)],
        createdAt: DateTime(2026, 9, 9),
      );

      expect(ride.avgSpeedKmh, closeTo(15.0, 0.01));
      // Invariant: max speed must never be less than avg speed
      expect(ride.maxSpeedKmh, closeTo(15.0, 0.01));
    });

    test('heals impossible maxSpeedKmh less than avgSpeedKmh', () {
      final ride = SharedRideEntity(
        id: 'r2',
        userId: 'u1',
        userName: 'Rider',
        userPhotoUrl: '',
        bikeId: 'b1',
        bikeName: 'CBR',
        bikeType: '160cc',
        rideDate: DateTime(2026, 9, 9),
        distanceKm: 4.0,
        durationSeconds: 960,
        maxSpeedKmh: 8.0, // Impossible: lower than 15 km/h avg
        polyline: const [],
        createdAt: DateTime(2026, 9, 9),
      );

      expect(ride.avgSpeedKmh, closeTo(15.0, 0.01));
      expect(ride.maxSpeedKmh, closeTo(15.0, 0.01));
    });

    test('preserves valid maxSpeedKmh greater than avgSpeedKmh', () {
      final ride = SharedRideEntity(
        id: 'r3',
        userId: 'u1',
        userName: 'Rider',
        userPhotoUrl: '',
        bikeId: 'b1',
        bikeName: 'CBR',
        bikeType: '160cc',
        rideDate: DateTime(2026, 9, 9),
        distanceKm: 4.0,
        durationSeconds: 960,
        maxSpeedKmh: 54.2, // Valid top speed
        polyline: const [],
        createdAt: DateTime(2026, 9, 9),
      );

      expect(ride.avgSpeedKmh, closeTo(15.0, 0.01));
      expect(ride.maxSpeedKmh, closeTo(54.2, 0.01));
    });

    test('permits zero maxSpeedKmh when distance is zero', () {
      final ride = SharedRideEntity(
        id: 'r4',
        userId: 'u1',
        userName: 'Rider',
        userPhotoUrl: '',
        bikeId: 'b1',
        bikeName: 'CBR',
        bikeType: '160cc',
        rideDate: DateTime(2026, 9, 9),
        distanceKm: 0.0,
        durationSeconds: 120,
        maxSpeedKmh: 0.0,
        polyline: const [],
        createdAt: DateTime(2026, 9, 9),
      );

      expect(ride.avgSpeedKmh, 0.0);
      expect(ride.maxSpeedKmh, 0.0);
    });
  });

  group('RideShareModel physical speed invariants', () {
    test('fromFirestore heals zero maxSpeedKmh for moving ride', () {
      final model = RideShareModel.fromFirestore({
        'userId': 'u1',
        'userName': 'Zulfikar',
        'userPhotoUrl': '',
        'bikeId': 'b1',
        'bikeName': 'Honda CBR',
        'bikeType': '160cc',
        'rideDate': '2026-09-09T10:00:00.000Z',
        'distanceKm': 4.0,
        'durationSeconds': 960,
        'maxSpeedKmh': 0.0,
        'createdAt': '2026-09-09T10:20:00.000Z',
      }, 'doc-1');

      expect(model.maxSpeedKmh, closeTo(15.0, 0.01));
      final entity = model.toEntity();
      expect(entity.maxSpeedKmh, closeTo(15.0, 0.01));
    });

    test('constructor guards maxSpeedKmh against being lower than avgSpeedKmh', () {
      final model = RideShareModel(
        id: 'm1',
        userId: 'u1',
        userName: 'Rider',
        userPhotoUrl: '',
        bikeId: 'b1',
        bikeName: 'CBR',
        bikeType: '160cc',
        rideDate: DateTime(2026, 9, 9),
        distanceKm: 10.0,
        durationSeconds: 600, // 60 km/h avg
        maxSpeedKmh: 20.0, // lower than avg
        polyline: const [],
        createdAt: DateTime(2026, 9, 9),
      );

      expect(model.maxSpeedKmh, closeTo(60.0, 0.01));
    });
  });
}
