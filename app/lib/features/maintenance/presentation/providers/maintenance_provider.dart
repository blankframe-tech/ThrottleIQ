import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../data/models/maintenance_model.dart';
import '../../../../core/database/daos/maintenance_dao.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../../../garage/presentation/providers/garage_provider.dart';

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
  }) async {
    final log = MaintenanceEntity(
      id: _uuid.v4(),
      bikeId: bikeId,
      serviceType: serviceType,
      date: date,
      odometerKm: odometerKm,
      cost: cost,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _dao.insert(MaintenanceModel.toMap(log));
    ref.invalidateSelf();
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

List<MaintenanceReminder> _computeReminders(
    double currentKm, List<MaintenanceEntity> logs) {
  final reminders = <MaintenanceReminder>[];
  final types = [
    ServiceType.oilChange,
    ServiceType.airFilter,
    ServiceType.chain,
    ServiceType.tire,
  ];

  for (final type in types) {
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
    default:
      return (0, double.infinity);
  }
}
