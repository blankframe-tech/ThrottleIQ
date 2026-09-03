import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../../../../core/database/daos/maintenance_dao.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/models/maintenance_model.dart';
import '../../domain/entities/maintenance_entity.dart';

const _uuid = Uuid();
final _dao = MaintenanceDao();

final maintenanceProvider =
    AsyncNotifierProvider.family<MaintenanceNotifier, List<MaintenanceEntity>, String>(
  MaintenanceNotifier.new,
);

class MaintenanceNotifier extends FamilyAsyncNotifier<List<MaintenanceEntity>, String> {
  @override
  Future<List<MaintenanceEntity>> build(String bikeId) async {
    final rows = await _dao.getForBike(bikeId);
    return rows.map(MaintenanceModel.fromMap).toList();
  }

  Future<void> addLog({
    required String bikeId,
    required ServiceType serviceType,
    required DateTime date,
    required double odometerKm,
    double? cost,
    String? notes,
    String? customLabel,
  }) async {
    final log = MaintenanceEntity(
      id: _uuid.v4(),
      bikeId: bikeId,
      serviceType: serviceType,
      date: date,
      odometerKm: odometerKm,
      cost: cost,
      notes: notes,
      // Only meaningful for ServiceType.custom; blanks are normalized to null
      // so displayLabel never has to distinguish '' from absent.
      customLabel: (customLabel != null && customLabel.trim().isNotEmpty)
          ? customLabel.trim()
          : null,
      createdAt: DateTime.now(),
    );
    final map = MaintenanceModel.toMap(log);
    await _dao.insert(map);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      unawaited(ref.read(outboxServiceProvider).enqueueMaintenanceLog(
        uid: user.uid,
        logData: map,
      ));
    }
    ref.invalidateSelf();
    // Keep the maintenance widget in step with what was just logged —
    // fire-and-forget, and a no-op wherever widgets aren't available.
    unawaited(HomeWidgetService.instance.refreshFromLocalData());
  }

  Future<void> deleteLog(String id) async {
    await _dao.delete(id);
    ref.invalidateSelf();
  }
}

final maintenanceRemindersProvider =
    Provider.family<List<MaintenanceReminder>, String>((ref, bikeId) {
  final bike = ref.watch(garageProvider).valueOrNull?.where((b) => b.id == bikeId).firstOrNull;
  final logs = ref.watch(maintenanceProvider(bikeId)).valueOrNull ?? [];
  if (bike == null) return [];
  return _computeReminders(bike.currentOdometerKm, logs);
});

/// Which service types get a proactive reminder card.
///
/// Deliberately NOT every [ServiceType]. The expanded list (spark plug,
/// valve clearance, suspension, …) is there so a rider can *log* what they
/// actually did, but rendering a reminder card per type would turn the
/// maintenance screen into a wall of mostly-green cards and bury the ones
/// that matter. Only the original four plus the two safety-critical brake
/// items are reminded on; everything else is log-only.
const _reminderTypes = [
  ServiceType.oilChange,
  ServiceType.airFilter,
  ServiceType.chain,
  ServiceType.tire,
  ServiceType.brakeFluid,
  ServiceType.frontDiscPads,
];

List<MaintenanceReminder> _computeReminders(
    double currentKm, List<MaintenanceEntity> logs) {
  final reminders = <MaintenanceReminder>[];

  for (final type in _reminderTypes) {
    final typeLogs = logs.where((l) => l.serviceType == type).toList()
      ..sort((a, b) => b.odometerKm.compareTo(a.odometerKm));

    final double lastKm = typeLogs.isEmpty ? 0 : typeLogs.first.odometerKm;
    final kmSince = currentKm - lastKm;
    final (minKm, maxKm) = _thresholds(type);

    final status = kmSince >= maxKm
        ? ReminderStatus.overdue
        : kmSince >= minKm
            ? ReminderStatus.dueSoon
            : ReminderStatus.ok;

    reminders.add(MaintenanceReminder(
      serviceType: type,
      status: status,
      kmSinceService: kmSince,
      kmLimit: maxKm,
      lastServiceDate: typeLogs.isEmpty ? null : typeLogs.first.date,
    ));
  }
  return reminders;
}

(double, double) _thresholds(ServiceType type) {
  switch (type) {
    case ServiceType.oilChange:
      return (SensorConstants.oilChangeMinKm, SensorConstants.oilChangeMaxKm);
    case ServiceType.airFilter:
      return (SensorConstants.airFilterMinKm, SensorConstants.airFilterMaxKm);
    case ServiceType.chain:
      return (SensorConstants.chainLubeMinKm, SensorConstants.chainLubeMaxKm);
    case ServiceType.tire:
      return (SensorConstants.tireCheckMinKm, SensorConstants.tireCheckMaxKm);
    case ServiceType.brakeFluid:
      return (SensorConstants.brakeFluidMinKm, SensorConstants.brakeFluidMaxKm);
    case ServiceType.frontDiscPads:
      return (SensorConstants.discPadsMinKm, SensorConstants.discPadsMaxKm);
    default:
      // Log-only types (see _reminderTypes): never overdue, never due soon.
      return (double.infinity, double.infinity);
  }
}
