import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_money.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/service_visit.dart';

void main() {
  final now = DateTime(2026, 10, 6);
  var n = 0;
  String newId() => 'id${n++}';
  setUp(() => n = 0);

  group('buildVisitLogs', () {
    test('a one-item visit stores the bill as the item cost', () {
      final rows = buildVisitLogs(
        bikeId: 'b',
        visitId: 'v',
        newId: newId,
        now: now,
        draft: VisitDraft(
          date: now,
          odometerKm: 12340,
          totalCost: 650,
          shopName: '  Rahim Motors ',
          shopKind: ShopKind.local,
          items: const [
            VisitItemDraft(
                type: ServiceType.oilChange,
                partBrand: 'Motul 3000',
                partGrade: 'mineral'),
          ],
        ),
      );
      expect(rows.single.cost, 650);
      expect(rows.single.visitTotal, isNull);
      expect(rows.single.shopName, 'Rahim Motors');
      expect(rows.single.partBrand, 'Motul 3000');
      expect(rows.single.visitId, 'v');
    });

    test('a multi-item visit keeps one bill, on every row', () {
      final rows = buildVisitLogs(
        bikeId: 'b',
        visitId: 'v',
        newId: newId,
        now: now,
        draft: VisitDraft(
          date: now,
          odometerKm: 100,
          totalCost: 1200,
          items: const [
            VisitItemDraft(type: ServiceType.oilChange),
            VisitItemDraft(type: ServiceType.chain),
            VisitItemDraft(type: ServiceType.airFilter, cost: 300),
          ],
        ),
      );
      expect(rows.map((r) => r.visitTotal).toSet(), {1200});
      expect(rows.map((r) => r.cost), [null, null, 300]);
      expect(ServiceVisit('v', rows).totalCost, 1200);
    });

    test('editing reuses the ids of items still ticked', () {
      final first = buildVisitLogs(
        bikeId: 'b',
        visitId: 'v',
        newId: newId,
        now: now,
        draft: VisitDraft(date: now, odometerKm: 1, items: const [
          VisitItemDraft(type: ServiceType.oilChange),
          VisitItemDraft(type: ServiceType.chain),
        ]),
      );
      final edited = buildVisitLogs(
        bikeId: 'b',
        visitId: 'v',
        newId: newId,
        now: now,
        existing: first,
        draft: VisitDraft(date: now, odometerKm: 2, items: const [
          VisitItemDraft(type: ServiceType.oilChange),
          VisitItemDraft(type: ServiceType.tire),
        ]),
      );
      expect(edited[0].id, first[0].id);
      expect(edited[1].id, isNot(anyOf(first[0].id, first[1].id)));
      expect(edited.every((r) => r.odometerKm == 2), isTrue);
    });
  });

  group('groupVisits', () {
    MaintenanceEntity row(String id, String? visit, DateTime d,
            {double? cost, double? total, String? label}) =>
        MaintenanceEntity(
          id: id,
          bikeId: 'b',
          serviceType: ServiceType.oilChange,
          date: d,
          odometerKm: 1,
          createdAt: d,
          visitId: visit,
          cost: cost,
          visitTotal: total,
          visitLabel: label,
        );

    test('older logs without a visit id are visits of one; newest first', () {
      final visits = groupVisits([
        row('a', null, DateTime(2026, 1, 1), cost: 100),
        row('b', 'v1', DateTime(2026, 5, 1), total: 900),
        row('c', 'v1', DateTime(2026, 5, 1), total: 900),
      ]);
      expect(visits.map((v) => v.id), ['v1', 'a']);
      expect(visits.first.items, hasLength(2));
      expect(totalSpend([
        row('a', null, DateTime(2026, 1, 1), cost: 100),
        row('b', 'v1', DateTime(2026, 5, 1), total: 900),
        row('c', 'v1', DateTime(2026, 5, 1), total: 900),
      ]), 1000);
    });

    test('free-service label is read back', () {
      final v = groupVisits([row('a', 'v', now, label: 'free:2')]).single;
      expect(v.freeServiceNumber, 2);
    });
  });

  group('computeMoney', () {
    MaintenanceEntity row(String id, String visit, ServiceType t, DateTime d,
            {double? cost, double? total}) =>
        MaintenanceEntity(
          id: id,
          bikeId: 'b',
          serviceType: t,
          date: d,
          odometerKm: 1,
          createdAt: d,
          visitId: visit,
          cost: cost,
          visitTotal: total,
        );

    test('per-km, monthly buckets and split', () {
      final money = computeMoney(
        now: now,
        distanceKm12m: 4000,
        fuelPricePerLitre: 130,
        kmPerLitre: 40,
        logs: [
          row('1', 'a', ServiceType.oilChange, DateTime(2026, 9, 10), cost: 650),
          row('2', 'b', ServiceType.chain, DateTime(2026, 10, 1), total: 1350),
          row('3', 'b', ServiceType.airFilter, DateTime(2026, 10, 1), total: 1350),
          // Older than 12 months: not in the per-km figure.
          row('4', 'c', ServiceType.tire, DateTime(2025, 1, 1), cost: 3000),
        ],
      );
      expect(money.spend12m, 2000);
      expect(money.maintenancePerKm, closeTo(0.5, 1e-9));
      expect(money.fuelPerKm, closeTo(3.25, 1e-9));
      expect(money.totalPerKm, closeTo(3.75, 1e-9));
      expect(money.split[SpendBucket.oil], 650);
      expect(money.split[SpendBucket.visit], 1350);
      expect(money.monthly.last.amount, 1350); // October
      expect(money.monthly[money.monthly.length - 2].amount, 650); // September
      expect(money.monthly, hasLength(6));
    });

    test('too little distance gives no per-km figure', () {
      final money = computeMoney(
        now: now,
        distanceKm12m: 10,
        logs: [row('1', 'a', ServiceType.oilChange, now, cost: 500)],
      );
      expect(money.maintenancePerKm, isNull);
      expect(money.isEmpty, isFalse);
    });
  });
}
