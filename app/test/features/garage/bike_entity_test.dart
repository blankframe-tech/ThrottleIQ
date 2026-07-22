import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';

void main() {
  group('BikeEntity.currentOdometerKm', () {
    final base = BikeEntity(
      id: 'bike1',
      userId: 'user1',
      brand: 'Yamaha',
      model: 'MT-15',
      totalDistanceM: 50000,
      createdAt: DateTime(2024, 1, 1),
    );

    test('falls back to just the GPS total when no baseline was set', () {
      expect(base.odometerKm, isNull);
      expect(base.currentOdometerKm, 50.0);
    });

    test('adds the manually-entered baseline to the GPS total', () {
      final withBaseline = base.copyWith(odometerKm: 12000);
      expect(withBaseline.currentOdometerKm, 12050.0);
    });

    test('copyWith preserves the baseline when not overridden', () {
      final withBaseline = base.copyWith(odometerKm: 5000);
      final updated = withBaseline.copyWith(cc: 155);
      expect(updated.odometerKm, 5000);
      expect(updated.currentOdometerKm, 5050.0);
    });
  });
}
