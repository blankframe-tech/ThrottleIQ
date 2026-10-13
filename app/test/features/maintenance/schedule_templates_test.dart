import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/riding_conditions.dart';
import 'package:throttleiq/features/maintenance/domain/catalog/schedule_templates.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

void main() {
  group('suggestTemplate', () {
    test('matches model names first', () {
      expect(suggestTemplate(brand: 'Bajaj', model: 'Pulsar 150', cc: 150).id,
          'bajaj_pulsar_150');
      expect(suggestTemplate(brand: 'Suzuki', model: 'Gixxer SF').id,
          'suzuki_gixxer');
      expect(suggestTemplate(brand: 'TVS', model: 'Apache RTR 160 4V').id,
          'tvs_apache_160');
      expect(suggestTemplate(brand: 'Yamaha', model: 'R15 V4').id, 'yamaha_r15');
    });

    test('falls back to engine size', () {
      expect(suggestTemplate(brand: 'Hero', model: 'Splendor', cc: 100).id,
          'generic_commuter');
      expect(suggestTemplate(brand: 'Runner', model: 'Knight Rider', cc: 150).id,
          'generic_mid');
      expect(suggestTemplate(brand: 'KTM', model: 'Duke', cc: 390).id,
          'generic_large');
    });

    test('nothing known → the default template', () {
      expect(suggestTemplate(brand: 'X', model: 'Y').id, kDefaultTemplateId);
      expect(templateById('nope').id, kDefaultTemplateId);
    });
  });

  test('every template keeps fuel off and has unique ids', () {
    final ids = kScheduleTemplates.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final t in kScheduleTemplates) {
      expect(t.enabledByDefault, isNot(contains(ServiceType.fuel)),
          reason: t.id);
      expect(t.enabledByDefault, contains(ServiceType.oilChange), reason: t.id);
    }
    // Only manual-checked schedules may claim to be verified.
    expect(kScheduleTemplates.where((t) => t.verified).map((t) => t.id),
        ['bajaj_pulsar_150']);
  });

  test('configsFromTemplate lists every built-in type, oil from the grade', () {
    final configs = configsFromTemplate(
      bikeId: 'b',
      template: templateById('bajaj_pulsar_150'),
      oilGrade: OilGrade.fullSynthetic,
    );
    expect(configs.length, ServiceType.values.length - 1); // minus custom
    final oil = configs.firstWhere((c) => c.serviceType == ServiceType.oilChange);
    expect(oil.intervalKm, 3500);
    expect(oil.intervalDays, 365);
    final valves =
        configs.firstWhere((c) => c.serviceType == ServiceType.valveClearance);
    expect(valves.isEnabled, isTrue);
    expect(valves.intervalKm, 10000);
  });

  test('retuneToTemplate leaves the rider\'s own intervals and custom checks', () {
    final current = [
      const MaintenanceConfigEntity(
          bikeId: 'b', serviceType: ServiceType.oilChange, intervalKm: 1800,
          source: IntervalSource.user),
      const MaintenanceConfigEntity(
          bikeId: 'b', serviceType: ServiceType.airFilter, intervalKm: 1),
      const MaintenanceConfigEntity(
          bikeId: 'b', serviceType: ServiceType.custom, intervalKm: 777,
          customId: 'c', customLabel: 'Horn'),
    ];
    final out = retuneToTemplate(
        current: current, template: templateById('generic_large'));
    expect(out[0].intervalKm, 1800);
    expect(out[1].intervalKm, 12000);
    expect(out[1].intervalDays, 365);
    expect(out[2].intervalKm, 777);
  });

  test('oil grades get longer intervals as the oil improves', () {
    final kms = OilGrade.values.map((g) => g.schedule.km).toList();
    expect(kms, orderedEquals([...kms]..sort()));
  });

  test('riding profile parses with a safe default', () {
    expect(RidingProfileExt.fromString('severe'), RidingProfile.severe);
    expect(RidingProfileExt.fromString(null), RidingProfile.normal);
    expect(RidingProfileExt.fromString('???'), RidingProfile.normal);
  });
}
