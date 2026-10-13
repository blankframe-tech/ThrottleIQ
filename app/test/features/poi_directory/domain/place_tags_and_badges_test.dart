import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/data/models/place_model.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/domain/place_tags.dart';

PlaceEntity _place({
  PlaceCategory category = PlaceCategory.garage,
  double ratingSum = 0,
  int ratingCount = 0,
  double googleRating = 0,
  Set<PlaceTag> tags = const {},
}) =>
    PlaceEntity(
      id: 'p',
      name: 'Central Moto Works',
      category: category,
      latitude: 23.8,
      longitude: 90.4,
      geohash: 'wh0r',
      address: '',
      createdBy: 'u',
      createdAt: DateTime(2026),
      ratingSum: ratingSum,
      ratingCount: ratingCount,
      googleRating: googleRating,
      tags: tags,
    );

void main() {
  group('Rider Approved', () {
    test('needs an average of at least 4.5 from at least 5 riders', () {
      expect(_place(ratingSum: 22.5, ratingCount: 5).isRiderApproved, isTrue);
      expect(_place(ratingSum: 24, ratingCount: 5).isRiderApproved, isTrue);
      expect(_place(ratingSum: 22, ratingCount: 5).isRiderApproved, isFalse, reason: '4.4 average');
      expect(_place(ratingSum: 20, ratingCount: 4).isRiderApproved, isFalse, reason: 'only 4 riders');
    });

    test('Google alone never earns it', () {
      expect(_place(googleRating: 5).isRiderApproved, isFalse);
    });

    test('safety points are never approved', () {
      expect(_place(category: PlaceCategory.police, ratingSum: 25, ratingCount: 5).isRiderApproved, isFalse);
    });

    test('sortRating prefers riders, then Google', () {
      expect(_place(ratingSum: 9, ratingCount: 2, googleRating: 4.9).sortRating, 4.5);
      expect(_place(googleRating: 4.2).sortRating, 4.2);
      expect(_place().sortRating, 0);
    });
  });

  group('PlaceCategory', () {
    test('cameras and checkposts are safety points, not destinations', () {
      expect(PlaceCategory.aiCamera.isSafetyPoint, isTrue);
      expect(PlaceCategory.police.isSafetyPoint, isTrue);
      expect(PlaceCategory.destinations,
          [PlaceCategory.fuel, PlaceCategory.garage, PlaceCategory.parts, PlaceCategory.recreation]);
    });
  });

  group('PlaceTag', () {
    test('parseAll keeps known names once and drops the rest', () {
      expect(PlaceTag.parseAll(['open24h', 'octane95', 'open24h', 'jetpack', 7, null]),
          {PlaceTag.open24h, PlaceTag.octane95});
      expect(PlaceTag.parseAll(null), isEmpty);
    });

    test('forCategory only offers tags that make sense there', () {
      expect(PlaceTag.forCategory(PlaceCategory.fuel), contains(PlaceTag.octane95));
      expect(PlaceTag.forCategory(PlaceCategory.garage), isNot(contains(PlaceTag.octane95)));
      expect(PlaceTag.forCategory(PlaceCategory.garage), contains(PlaceTag.efiDiagnostics));
      expect(PlaceTag.forCategory(PlaceCategory.aiCamera), isEmpty);
      expect(PlaceTag.forCategory(PlaceCategory.police), isEmpty);
    });

    test('the per-place cap fits every tag', () {
      expect(PlaceTag.values.length, lessThanOrEqualTo(PlaceTag.maxPerPlace));
    });
  });

  group('PlaceModel tags', () {
    test('round-trip through the entity in a stable order', () {
      final entity = _place(tags: {PlaceTag.paddockStand, PlaceTag.efiDiagnostics});
      final model = PlaceModel.fromEntity(entity);
      expect(model.tags, ['efiDiagnostics', 'paddockStand']);
      expect(model.toEntity().tags, entity.tags);
      expect(model.toFirestore()['tags'], ['efiDiagnostics', 'paddockStand']);
    });

    test('a tagless place writes no tags field, keeping the old doc shape', () {
      final json = PlaceModel.fromEntity(_place()).toFirestore();
      expect(json.containsKey('tags'), isFalse);
      // The create rule compares these as before.
      expect(json['createdAt'], isA<Timestamp>());
    });
  });
}
