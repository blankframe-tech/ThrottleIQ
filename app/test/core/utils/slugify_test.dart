import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/slugify.dart';

void main() {
  group('bikeForumSlug', () {
    test('slugifies a brand-only forum', () {
      expect(bikeForumSlug('Yamaha'), 'yamaha');
    });

    test('slugifies a brand+model forum', () {
      expect(bikeForumSlug('Yamaha', model: 'MT-15'), 'yamaha__mt_15');
    });

    test('hyphen, space, and underscore in a model all collapse to the same slug', () {
      final hyphenated = bikeForumSlug('Yamaha', model: 'MT-15');
      final spaced = bikeForumSlug('Yamaha', model: 'MT 15');
      final underscored = bikeForumSlug('Yamaha', model: 'MT_15');
      expect(hyphenated, 'yamaha__mt_15');
      expect(spaced, hyphenated);
      expect(underscored, hyphenated);
    });

    test('is case-insensitive and trims whitespace', () {
      expect(bikeForumSlug('  Yamaha  '), bikeForumSlug('yamaha'));
      expect(
        bikeForumSlug('YAMAHA', model: '  mt-15  '),
        bikeForumSlug('yamaha', model: 'MT-15'),
      );
    });

    test('collapses internal whitespace to underscores', () {
      expect(bikeForumSlug('Royal Enfield'), 'royal_enfield');
    });

    test('a blank/whitespace-only model is treated as no model', () {
      expect(bikeForumSlug('Yamaha', model: '   '), bikeForumSlug('Yamaha'));
      expect(bikeForumSlug('Yamaha', model: ''), 'yamaha');
    });

    test('is deterministic across repeated calls', () {
      expect(
        bikeForumSlug('Honda', model: 'CB350'),
        bikeForumSlug('Honda', model: 'CB350'),
      );
    });

    test('brand/model boundary cannot collide across different splits', () {
      final a = bikeForumSlug('Royal Enfield', model: 'Classic 350');
      final b = bikeForumSlug('Royal', model: 'Enfield Classic 350');
      expect(a, 'royal_enfield__classic_350');
      expect(b, 'royal__enfield_classic_350');
      expect(a, isNot(equals(b)));
    });
  });

  group('generalForumSlug', () {
    test('slugifies a single-word topic', () {
      expect(generalForumSlug('Maintenance'), 'maintenance');
    });

    test('collapses hyphens and spaces the same way as bikeForumSlug', () {
      expect(generalForumSlug('Two-Strokes'), 'two_strokes');
      expect(generalForumSlug('Dirt Bikes'), 'dirt_bikes');
      expect(generalForumSlug('Two-Strokes'), generalForumSlug('Two Strokes'));
    });
  });
}
