import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/bike_catalog.dart';

void main() {
  group('modelsForBrand', () {
    test('returns the catalog models for an exact brand match', () {
      expect(modelsForBrand('Yamaha'), contains('FZS'));
    });

    test('is case and whitespace insensitive', () {
      expect(modelsForBrand('  yamaha  '), modelsForBrand('Yamaha'));
      expect(modelsForBrand('YAMAHA'), modelsForBrand('Yamaha'));
    });

    test('a brand not in the catalog returns no suggestions, not an error', () {
      expect(modelsForBrand('SomeCustomBrand'), isEmpty);
    });

    test('an empty brand returns no suggestions', () {
      expect(modelsForBrand(''), isEmpty);
    });
  });

  group('bikeCatalogBrands', () {
    test('lists every brand key in the catalog', () {
      expect(bikeCatalogBrands, containsAll(['Yamaha', 'Honda', 'Royal Enfield']));
      expect(bikeCatalogBrands.length, bikeCatalog.length);
    });
  });
}
