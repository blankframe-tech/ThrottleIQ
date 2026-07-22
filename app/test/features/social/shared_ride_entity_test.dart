import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';

void main() {
  group('SharedRideEntity', () {
    final testPolyline = [
      LatLng(0.0, 0.0),
      LatLng(0.001, 0.001),
      LatLng(0.002, 0.002),
    ];

    final testRide = SharedRideEntity(
      id: 'ride1',
      userId: 'user1',
      userName: 'John Doe',
      userPhotoUrl: 'http://example.com/photo.jpg',
      bikeId: 'bike1',
      bikeName: 'My Harley',
      bikeType: 'Cruiser',
      rideDate: DateTime(2024, 1, 15),
      distanceKm: 50.0,
      durationSeconds: 3600, // 1 hour
      maxSpeedKmh: 100.0,
      polyline: testPolyline,
      createdAt: DateTime.now(),
    );

    test('calculates duration in minutes correctly', () {
      expect(testRide.durationMinutes, 60);
    });

    test('calculates average speed correctly', () {
      expect(testRide.avgSpeedKmh, 50.0);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = testRide.copyWith(
        likes: 5,
        isLikedByCurrentUser: true,
      );

      expect(updated.id, testRide.id);
      expect(updated.userId, testRide.userId);
      expect(updated.likes, 5);
      expect(updated.isLikedByCurrentUser, true);
    });

    test('copyWith updates specified fields', () {
      final updated = testRide.copyWith(
        likes: 10,
        comments: 3,
      );

      expect(updated.likes, 10);
      expect(updated.comments, 3);
      expect(updated.distanceKm, testRide.distanceKm);
    });

    test('props include critical identifiers', () {
      expect(
        testRide.props,
        contains(testRide.id),
      );
      expect(
        testRide.props,
        contains(testRide.userId),
      );
    });

    test('ride with followers-only visibility', () {
      final followersRide = testRide.copyWith(
        audience: 'followers',
        allowedUserIds: ['user2', 'user3'],
      );

      expect(followersRide.audience, 'followers');
      expect(followersRide.allowedUserIds.length, 2);
    });

    test('ride with zero duration handles division', () {
      final zeroRide = SharedRideEntity(
        id: 'ride2',
        userId: 'user2',
        userName: 'Jane Doe',
        userPhotoUrl: 'http://example.com/photo2.jpg',
        bikeId: 'bike2',
        bikeName: 'My Bike',
        bikeType: 'Sport',
        rideDate: DateTime.now(),
        distanceKm: 10.0,
        durationSeconds: 0,
        maxSpeedKmh: 50.0,
        polyline: testPolyline,
        createdAt: DateTime.now(),
      );

      expect(zeroRide.avgSpeedKmh, 0.0);
    });

    test('can link to saved route', () {
      final routedRide = testRide.copyWith();
      final withRoute = SharedRideEntity(
        id: routedRide.id,
        userId: routedRide.userId,
        userName: routedRide.userName,
        userPhotoUrl: routedRide.userPhotoUrl,
        bikeId: routedRide.bikeId,
        bikeName: routedRide.bikeName,
        bikeType: routedRide.bikeType,
        rideDate: routedRide.rideDate,
        distanceKm: routedRide.distanceKm,
        durationSeconds: routedRide.durationSeconds,
        maxSpeedKmh: routedRide.maxSpeedKmh,
        polyline: routedRide.polyline,
        createdAt: routedRide.createdAt,
        routeId: 'route123',
      );

      expect(withRoute.routeId, 'route123');
    });
  });
}
