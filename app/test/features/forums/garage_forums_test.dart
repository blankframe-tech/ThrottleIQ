import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/presentation/providers/forum_providers.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';

/// Which forums a garage puts in "Your bikes", and the cache signature that
/// decides when that list has to be re-resolved from Firestore.
///
/// The behaviour under test: owning a bike enrols you in **that bike's**
/// forum and nothing above it. It used to also enrol you in the brand forum,
/// which meant a rider with one Yamaha RXS 1154 got every thread about every
/// Yamaha ever made pinned to their own bikes list.
BikeEntity bike(String id, String brand, String model) => BikeEntity(
      id: id,
      userId: 'u1',
      brand: brand,
      model: model,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('garageForumTargets', () {
    test('one forum per bike — the model, never the brand', () {
      final targets = garageForumTargets([bike('b1', 'Yamaha', 'RXS 1154')]);

      expect(targets.map((t) => t.slug), ['yamaha__rxs_1154']);
      expect(targets.single.brand, 'Yamaha');
      expect(targets.single.model, 'RXS 1154');
    });

    test('two bikes of the same brand do not collapse into it', () {
      final targets = garageForumTargets([
        bike('b1', 'Yamaha', 'RXS 1154'),
        bike('b2', 'Yamaha', 'MT-15'),
      ]);

      expect(targets.map((t) => t.slug), ['yamaha__rxs_1154', 'yamaha__mt_15']);
      expect(targets.map((t) => t.slug), isNot(contains('yamaha')));
    });

    test('duplicate bikes share one forum, however they were typed', () {
      // Two of the same bike in the garage is one conversation, not two —
      // and `bikeForumSlug` normalises case and separator style, so a rider
      // who typed "MT-15" once and "mt 15" the next time lands on one forum.
      final targets = garageForumTargets([
        bike('b1', 'Yamaha', 'MT-15'),
        bike('b2', 'yamaha', 'mt 15'),
      ]);

      expect(targets, hasLength(1));
      expect(targets.single.slug, 'yamaha__mt_15');
    });

    test('a bike with no model contributes nothing', () {
      // Its only slug would be the bare brand forum, which is exactly what
      // this list no longer auto-enrols anyone in.
      expect(garageForumTargets([bike('b1', 'Yamaha', '   ')]), isEmpty);
    });
  });

  group('garageForumsSignature', () {
    test('is stable across garage ordering', () {
      final a = [bike('b1', 'Yamaha', 'RX100'), bike('b2', 'Honda', 'CB350')];
      final b = [bike('b2', 'Honda', 'CB350'), bike('b1', 'Yamaha', 'RX100')];

      expect(garageForumsSignature(a), garageForumsSignature(b));
    });

    test('changes when a genuinely new bike is added', () {
      final before = [bike('b1', 'Yamaha', 'RX100')];
      final after = [...before, bike('b2', 'Honda', 'CB350')];

      expect(garageForumsSignature(after), isNot(garageForumsSignature(before)));
    });

    test('does not change when a second bike of the same model is added', () {
      final before = [bike('b1', 'Yamaha', 'RX100')];
      final after = [...before, bike('b2', 'Yamaha', 'RX100')];

      expect(garageForumsSignature(after), garageForumsSignature(before));
    });

    test('an empty garage has an empty signature', () {
      expect(garageForumsSignature(const []), '');
    });

    test('carries no bare brand slug', () {
      // The regression guard: a signature containing `yamaha` on its own
      // means the brand forum crept back into the derived set.
      final signature = garageForumsSignature([bike('b1', 'Yamaha', 'RX100')]);
      expect(signature.split(','), isNot(contains('yamaha')));
    });
  });
}
