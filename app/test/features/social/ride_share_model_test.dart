import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/social/data/models/ride_share_model.dart';

void main() {
  group('RideShareModel', () {
    final polyline = [
      LatLng(40.7128, -74.0060),
      LatLng(40.7200, -74.0100),
      LatLng(40.7300, -74.0150),
    ];

    final model = RideShareModel(
      id: 'ride1',
      userId: 'user1',
      userName: 'John Doe',
      userPhotoUrl: 'http://example.com/photo.jpg',
      bikeId: 'bike1',
      bikeName: 'My Harley',
      bikeType: 'Cruiser',
      rideDate: DateTime(2024, 1, 15),
      distanceKm: 50.0,
      durationSeconds: 3600,
      maxSpeedKmh: 100.0,
      polyline: polyline,
      createdAt: DateTime(2024, 1, 15, 12, 0),
    );

    test('converts to Firestore format', () {
      final firestoreData = model.toFirestore();

      expect(firestoreData['id'], 'ride1');
      expect(firestoreData['userId'], 'user1');
      expect(firestoreData['distanceKm'], 50.0);
      expect(firestoreData['polyline'], isA<List>());
      expect(firestoreData['polyline'].length, 3);
    });

    test('polyline serialization format', () {
      final firestoreData = model.toFirestore();
      final polylineData = firestoreData['polyline'] as List;

      expect(polylineData[0], {'lat': 40.7128, 'lng': -74.0060});
    });

    test('converts from Firestore format', () {
      final firestoreData = {
        'id': 'ride1',
        'userId': 'user1',
        'userName': 'John Doe',
        'userPhotoUrl': 'http://example.com/photo.jpg',
        'bikeId': 'bike1',
        'bikeName': 'My Harley',
        'bikeType': 'Cruiser',
        'rideDate': DateTime(2024, 1, 15),
        'distanceKm': 50.0,
        'durationSeconds': 3600,
        'maxSpeedKmh': 100.0,
        'polyline': [
          {'lat': 40.7128, 'lng': -74.0060},
          {'lat': 40.7200, 'lng': -74.0100},
          {'lat': 40.7300, 'lng': -74.0150},
        ],
        'mapSnapshotUrl': null,
        'likes': 5,
        'comments': 2,
        'createdAt': DateTime(2024, 1, 15, 12, 0),
        'isPrivate': false,
        'allowedUserIds': [],
        'routeId': null,
      };

      final restored = RideShareModel.fromFirestore(firestoreData, 'ride1');

      expect(restored.id, 'ride1');
      expect(restored.userId, 'user1');
      expect(restored.distanceKm, 50.0);
      expect(restored.polyline.length, 3);
      expect(restored.likes, 5);
    });

    test('converts to entity', () {
      final entity = model.toEntity();

      expect(entity.id, model.id);
      expect(entity.userId, model.userId);
      expect(entity.distanceKm, model.distanceKm);
      expect(entity.polyline, model.polyline);
    });

    test('handles private rides with allowed users', () {
      final privateModel = RideShareModel(
        id: 'ride2',
        userId: 'user1',
        userName: 'John Doe',
        userPhotoUrl: 'http://example.com/photo.jpg',
        bikeId: 'bike1',
        bikeName: 'My Harley',
        bikeType: 'Cruiser',
        rideDate: DateTime.now(),
        distanceKm: 30.0,
        durationSeconds: 1800,
        maxSpeedKmh: 80.0,
        polyline: polyline,
        createdAt: DateTime.now(),
        isPrivate: true,
        allowedUserIds: ['user2', 'user3'],
      );

      final firestoreData = privateModel.toFirestore();
      expect(firestoreData['isPrivate'], true);
      expect(firestoreData['allowedUserIds'], ['user2', 'user3']);
    });

    test('handles route reference', () {
      final routedModel = RideShareModel(
        id: 'ride3',
        userId: 'user1',
        userName: 'John Doe',
        userPhotoUrl: 'http://example.com/photo.jpg',
        bikeId: 'bike1',
        bikeName: 'My Harley',
        bikeType: 'Cruiser',
        rideDate: DateTime.now(),
        distanceKm: 25.0,
        durationSeconds: 1200,
        maxSpeedKmh: 75.0,
        polyline: polyline,
        createdAt: DateTime.now(),
        routeId: 'route123',
      );

      final firestoreData = routedModel.toFirestore();
      expect(firestoreData['routeId'], 'route123');

      final restored = RideShareModel.fromFirestore(firestoreData, 'ride3');
      expect(restored.routeId, 'route123');
    });

    test('handles missing optional fields', () {
      final minimalData = {
        'userId': 'user1',
        'userName': 'John Doe',
        'userPhotoUrl': 'http://example.com/photo.jpg',
        'bikeId': 'bike1',
        'bikeName': 'My Harley',
        'bikeType': 'Cruiser',
        'rideDate': DateTime.now(),
        'distanceKm': 30.0,
        'durationSeconds': 1800,
        'maxSpeedKmh': 80.0,
        'polyline': [],
        'createdAt': DateTime.now(),
      };

      final restored = RideShareModel.fromFirestore(minimalData, 'ride1');

      expect(restored.mapSnapshotUrl, null);
      expect(restored.likes, 0);
      expect(restored.comments, 0);
      expect(restored.isPrivate, false);
    });
  });
}
