import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/data/models/fuel_log_model.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';

void main() {
  final entity = FuelLogEntity(
    id: 'f1',
    bikeId: 'b1',
    filledAt: DateTime(2026, 10, 1, 9, 30),
    odometerKm: 12500.5,
    liters: 6.25,
    totalCost: 812.5,
    pricePerLiter: 130,
    fullTank: false,
    station: 'Meghna',
    note: 'highway',
    createdAt: DateTime(2026, 10, 1, 9, 31),
    updatedAt: DateTime(2026, 10, 2),
  );

  test('row round-trip keeps every field', () {
    final row = FuelLogModel.toMap(entity);
    expect(row['full_tank'], 0);
    expect(row['synced'], 0);
    expect(FuelLogModel.fromMap(row), entity);
  });

  test('blank station and note are stored as null', () {
    final row = FuelLogModel.toMap(entity.copyWith(station: '  ', note: ''));
    expect(row['station'], isNull);
    expect(row['note'], isNull);
  });

  test('cloud payload: fixed key set, real bool, no local sync flag', () {
    final payload = FuelLogModel.toCloudPayload(FuelLogModel.toMap(entity));
    expect(payload.keys.toSet(), FuelLogModel.cloudKeys.toSet());
    expect(payload['full_tank'], isFalse);
    expect(payload, isNot(contains('synced')));
    expect(payload['odometer_km'], 12500.5);
    expect(payload['filled_at'], '2026-10-01T09:30:00.000');
  });

  test('cloud payload omits null optionals and unknown columns', () {
    final row = FuelLogModel.toMap(entity.copyWith())
      ..['station'] = null
      ..['note'] = null
      ..['some_future_column'] = 1;
    final payload = FuelLogModel.toCloudPayload(row);
    expect(payload, isNot(contains('station')));
    expect(payload, isNot(contains('note')));
    expect(payload, isNot(contains('some_future_column')));
  });

  test('downloaded doc becomes a synced row equal to the original', () {
    final doc = {
      ...FuelLogModel.toCloudPayload(FuelLogModel.toMap(entity)),
      'syncedAt': 'server-timestamp',
    };
    final row = FuelLogModel.fromCloud(doc)!;
    expect(row['synced'], 1);
    expect(row['full_tank'], 0);
    expect(row, isNot(contains('syncedAt')));
    expect(FuelLogModel.fromMap(row), entity);
  });

  test('a doc missing required fields is skipped', () {
    final doc = FuelLogModel.toCloudPayload(FuelLogModel.toMap(entity))
      ..remove('liters');
    expect(FuelLogModel.fromCloud(doc), isNull);
  });
}
