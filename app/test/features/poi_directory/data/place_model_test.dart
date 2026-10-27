import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/data/models/place_model.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

void main() {
  // PlaceEntity / PlaceModel only; PlaceRepository's queries are covered by
  // repositories/place_nearby_query_test.dart.
  group('Place Rating Aggregation', () {
    test('average rating calculation', () {
      final placeWithRatings = PlaceEntity(
        id: 'place1',
        name: 'Test Place',
        category: PlaceCategory.fuel,
        latitude: 23.8103,
        longitude: 90.4125,
        geohash: 'twyv',
        address: 'Test Address',
        verified: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        ratingSum: 20, // 5 ratings of 4 stars each
        ratingCount: 5,
      );

      expect(placeWithRatings.averageRating, equals(4.0));
    });

    test('average rating with zero reviews', () {
      final placeNoRatings = PlaceEntity(
        id: 'place1',
        name: 'Test Place',
        category: PlaceCategory.fuel,
        latitude: 23.8103,
        longitude: 90.4125,
        geohash: 'twyv',
        address: 'Test Address',
        verified: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        ratingSum: 0,
        ratingCount: 0,
      );

      expect(placeNoRatings.averageRating, equals(0.0));
    });
  });

  group('PlaceModel Conversions', () {
    test('PlaceModel.fromEntity converts correctly', () {
      final testPlace = PlaceEntity(
        id: 'place1',
        name: 'Test Fuel Station',
        category: PlaceCategory.fuel,
        latitude: 23.8103,
        longitude: 90.4125,
        geohash: 'twyv',
        address: 'Test Address',
        verified: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
      );

      final model = PlaceModel.fromEntity(testPlace);

      expect(model.id, equals(testPlace.id));
      expect(model.name, equals(testPlace.name));
      expect(model.category, equals('fuel'));
      expect(model.latitude, equals(testPlace.latitude));
      expect(model.longitude, equals(testPlace.longitude));
    });

    test('PlaceModel.toEntity converts correctly', () {
      final model = PlaceModel(
        id: 'place1',
        name: 'Test Fuel Station',
        category: 'fuel',
        latitude: 23.8103,
        longitude: 90.4125,
        geohash: 'twyv',
        address: 'Test Address',
        verified: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
      );

      final entity = model.toEntity();

      expect(entity.id, equals(model.id));
      expect(entity.name, equals(model.name));
      expect(entity.category, equals(PlaceCategory.fuel));
      expect(entity.latitude, equals(model.latitude));
      expect(entity.longitude, equals(model.longitude));
    });

    test('PlaceModel.toFirestore creates valid document', () {
      final model = PlaceModel(
        id: 'place1',
        name: 'Test Fuel Station',
        category: 'fuel',
        latitude: 23.8103,
        longitude: 90.4125,
        geohash: 'twyv',
        address: 'Test Address',
        verified: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
      );

      final firestore = model.toFirestore();

      expect(firestore, isA<Map<String, dynamic>>());
      expect(firestore['name'], equals('Test Fuel Station'));
      expect(firestore['category'], equals('fuel'));
      expect(firestore['verified'], equals(false));
      expect(firestore['createdBy'], equals('user1'));
      expect(firestore['googleRating'], equals(0.0));
      expect(firestore['googleRatingCount'], equals(0));
    });

    test('PlaceModel preserves googleRating across conversions', () {
      final model = PlaceModel(
        id: 'place1',
        name: 'Trust CNG',
        category: 'fuel',
        latitude: 23.8,
        longitude: 90.4,
        geohash: 'wh0r',
        address: 'Dhaka',
        verified: true,
        createdBy: 'system:osm-seed-dhaka',
        createdAt: DateTime(2024, 1, 1),
        googleRating: 4.3,
        googleRatingCount: 515,
        ratingSum: 10,
        ratingCount: 2,
      );

      final entity = model.toEntity();
      expect(entity.googleRating, 4.3);
      expect(entity.googleRatingCount, 515);
      expect(entity.averageRating, 5.0);

      final backToModel = PlaceModel.fromEntity(entity);
      expect(backToModel.googleRating, 4.3);
      expect(backToModel.googleRatingCount, 515);

      final json = backToModel.toFirestore();
      expect(json['googleRating'], 4.3);
      expect(json['googleRatingCount'], 515);
    });

    test('PlaceModel round-trip with expiresAt', () {
      final expires = DateTime.utc(2026, 10, 18, 14);
      final entity = PlaceEntity(
        id: 'place_exp',
        name: 'Police Checkpoint',
        category: PlaceCategory.police,
        latitude: 23.8,
        longitude: 90.4,
        geohash: 'wh0r',
        address: 'Airport Road',
        createdBy: 'user1',
        createdAt: DateTime.utc(2026, 10, 17, 14),
        expiresAt: expires,
      );

      final model = PlaceModel.fromEntity(entity);
      expect(model.expiresAt, expires);

      final roundTrip = model.toEntity();
      expect(roundTrip.expiresAt?.isAtSameMomentAs(expires), isTrue);
      expect(roundTrip.isExpiredAt(DateTime.utc(2026, 10, 18, 15)), isTrue);
      expect(roundTrip.isExpiredAt(DateTime.utc(2026, 10, 18, 13)), isFalse);

      final firestore = model.toFirestore();
      expect(firestore.containsKey('expiresAt'), isTrue);
      expect(
          (firestore['expiresAt'] as Timestamp)
              .toDate()
              .isAtSameMomentAs(expires),
          isTrue);
    });

    test('PlaceModel without expiresAt leaves key out of toFirestore', () {
      final entity = PlaceEntity(
        id: 'place_perm',
        name: 'Permanent Station',
        category: PlaceCategory.police,
        latitude: 23.8,
        longitude: 90.4,
        geohash: 'wh0r',
        address: '',
        createdBy: 'user1',
        createdAt: DateTime.utc(2026, 10, 17, 14),
      );

      final model = PlaceModel.fromEntity(entity);
      expect(model.expiresAt, isNull);

      final roundTrip = model.toEntity();
      expect(roundTrip.expiresAt, isNull);
      expect(roundTrip.isExpiredAt(DateTime.utc(2030)), isFalse);

      final firestore = model.toFirestore();
      expect(firestore.containsKey('expiresAt'), isFalse);
    });
  });
}
