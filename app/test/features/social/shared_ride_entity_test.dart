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

    test('caption defaults to null and copyWith can set it', () {
      expect(testRide.caption, isNull);

      final captioned = testRide.copyWith(caption: 'Coast road at sunrise');
      expect(captioned.caption, 'Coast road at sunrise');
    });

    test('copyWith preserves an existing caption when not overridden', () {
      final captioned = testRide.copyWith(caption: 'Original caption');
      final voted = captioned.copyWith(upvotes: 3);

      expect(voted.caption, 'Original caption');
      expect(voted.upvotes, 3);
    });

    test('copyWith overrides an existing caption', () {
      final captioned = testRide.copyWith(caption: 'Original caption');
      final rewritten = captioned.copyWith(caption: 'New caption');

      expect(rewritten.caption, 'New caption');
    });

    test('caption participates in equality', () {
      final a = testRide.copyWith(caption: 'A');
      final b = testRide.copyWith(caption: 'B');

      expect(a, isNot(equals(b)));
      expect(a, equals(testRide.copyWith(caption: 'A')));
    });

    test('has no photos by default', () {
      expect(testRide.photoUrls, isEmpty);
      expect(testRide.photoUrl, isNull);
    });

    test('photoUrl exposes the lead photo of the list', () {
      final withPhotos = testRide.copyWith(photoUrls: const ['a.jpg', 'b.jpg']);

      expect(withPhotos.photoUrl, 'a.jpg');
      expect(withPhotos.photoUrls, ['a.jpg', 'b.jpg']);
    });

    test('copyWith preserves photos when not overridden', () {
      final withPhotos = testRide.copyWith(photoUrls: const ['a.jpg']);
      final voted = withPhotos.copyWith(upvotes: 2);

      expect(voted.photoUrls, ['a.jpg']);
    });

    test('photos participate in equality', () {
      final a = testRide.copyWith(photoUrls: const ['a.jpg']);
      final b = testRide.copyWith(photoUrls: const ['b.jpg']);

      expect(a, isNot(equals(b)));
      expect(a, equals(testRide.copyWith(photoUrls: const ['a.jpg'])));
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

  group('normalizeRidePhotoUrls', () {
    test('keeps order and passes through a clean list', () {
      expect(normalizeRidePhotoUrls(const ['a.jpg', 'b.jpg']), ['a.jpg', 'b.jpg']);
    });

    test('caps at three photos', () {
      expect(
        normalizeRidePhotoUrls(const ['a', 'b', 'c', 'd', 'e']),
        ['a', 'b', 'c'],
      );
      expect(kMaxRidePhotos, 3);
    });

    test('drops nulls, blanks and duplicates, and trims', () {
      expect(
        normalizeRidePhotoUrls(const [' a.jpg ', '', null, 'a.jpg', '   ', 'b.jpg']),
        ['a.jpg', 'b.jpg'],
      );
    });

    test('falls back to the legacy single photoUrl when the list is empty', () {
      expect(
        normalizeRidePhotoUrls(null, legacyPhotoUrl: 'legacy.jpg'),
        ['legacy.jpg'],
      );
      expect(
        normalizeRidePhotoUrls(const [], legacyPhotoUrl: 'legacy.jpg'),
        ['legacy.jpg'],
      );
    });

    test('ignores the legacy photoUrl when the list has photos', () {
      expect(
        normalizeRidePhotoUrls(const ['new.jpg'], legacyPhotoUrl: 'new.jpg'),
        ['new.jpg'],
      );
      expect(
        normalizeRidePhotoUrls(const ['a.jpg', 'b.jpg'], legacyPhotoUrl: 'a.jpg'),
        ['a.jpg', 'b.jpg'],
      );
    });

    test('yields nothing when there is nothing to keep', () {
      expect(normalizeRidePhotoUrls(null), isEmpty);
      expect(normalizeRidePhotoUrls(const [null, '', '  ']), isEmpty);
      expect(normalizeRidePhotoUrls(const [], legacyPhotoUrl: '  '), isEmpty);
    });
  });
}
