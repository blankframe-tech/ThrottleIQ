import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/database/daos/maintenance_dao.dart';
import '../../../../core/database/daos/maintenance_config_dao.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/models/maintenance_model.dart';
import '../../data/models/maintenance_config_model.dart';
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

final _configDao = MaintenanceConfigDao();

final isMaintenanceCustomizedProvider =
    FutureProvider.family<bool, String>((ref, bikeId) async {
  return _configDao.hasCustomized(bikeId);
});

final maintenanceConfigProvider = AsyncNotifierProvider.family<
    MaintenanceConfigNotifier, List<MaintenanceConfigEntity>, String>(
  MaintenanceConfigNotifier.new,
);

class MaintenanceConfigNotifier
    extends FamilyAsyncNotifier<List<MaintenanceConfigEntity>, String> {
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async {
    final rows = await _configDao.getConfigsForBike(bikeId);
    if (rows.isNotEmpty) {
      final savedConfigs = rows.map(MaintenanceConfigModel.fromMap).toList();
      final existingTypes = savedConfigs.map((c) => c.serviceType).toSet();
      final fullList = <MaintenanceConfigEntity>[...savedConfigs];
      for (final type in ServiceType.values) {
        if (type == ServiceType.custom) continue;
        if (!existingTypes.contains(type)) {
          fullList.add(MaintenanceConfigEntity(
            bikeId: bikeId,
            serviceType: type,
            intervalKm: type.defaultIntervalKm,
            isEnabled: false,
          ));
        }
      }
      return fullList;
    }

    // Default template when not yet customized:
    return ServiceType.values
        .where((t) => t != ServiceType.custom)
        .map((t) => MaintenanceConfigEntity(
              bikeId: bikeId,
              serviceType: t,
              intervalKm: t.defaultIntervalKm,
              isEnabled: t.isRecommendedDefault,
            ))
        .toList();
  }

  Future<void> saveConfigs(List<MaintenanceConfigEntity> configs) async {
    final bikeId = arg;
    final maps = configs.map(MaintenanceConfigModel.toMap).toList();
    await _configDao.saveConfigsForBike(bikeId, maps);
    ref.invalidateSelf();
    ref.invalidate(isMaintenanceCustomizedProvider(bikeId));
    ref.invalidate(maintenanceRemindersProvider(bikeId));
    unawaited(HomeWidgetService.instance.refreshFromLocalData());
  }
}

final maintenanceRemindersProvider =
    Provider.family<List<MaintenanceReminder>, String>((ref, bikeId) {
  final bike = ref.watch(garageProvider).valueOrNull?.where((b) => b.id == bikeId).firstOrNull;
  final logs = ref.watch(maintenanceProvider(bikeId)).valueOrNull ?? [];
  final configs = ref.watch(maintenanceConfigProvider(bikeId)).valueOrNull ?? [];
  if (bike == null) return [];
  return _computeReminders(bike.currentOdometerKm, logs, configs);
});

List<MaintenanceReminder> _computeReminders(
    double currentKm,
    List<MaintenanceEntity> logs,
    List<MaintenanceConfigEntity> configs) {
  final reminders = <MaintenanceReminder>[];
  final enabledConfigs = configs.where((c) => c.isEnabled).toList();

  for (final config in enabledConfigs) {
    final type = config.serviceType;
    final typeLogs = logs.where((l) => l.serviceType == type).toList()
      ..sort((a, b) => b.odometerKm.compareTo(a.odometerKm));

    final double lastKm = typeLogs.isEmpty ? 0 : typeLogs.first.odometerKm;
    final kmSince = currentKm - lastKm;
    final maxKm = config.intervalKm;
    final dueSoonThreshold = maxKm > 1000 ? maxKm * 0.8 : (maxKm - 150).clamp(0.0, maxKm);

    final status = kmSince >= maxKm
        ? ReminderStatus.overdue
        : kmSince >= dueSoonThreshold
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

  // Sort: Overdue first, then Due Soon, then OK. Inside same status, highest wear ratio first.
  reminders.sort((a, b) {
    int rank(ReminderStatus s) => switch (s) {
          ReminderStatus.overdue => 0,
          ReminderStatus.dueSoon => 1,
          ReminderStatus.ok => 2,
        };
    final rankDiff = rank(a.status).compareTo(rank(b.status));
    if (rankDiff != 0) return rankDiff;
    final aRatio = a.kmLimit > 0 ? a.kmSinceService / a.kmLimit : 0.0;
    final bRatio = b.kmLimit > 0 ? b.kmSinceService / b.kmLimit : 0.0;
    return bRatio.compareTo(aRatio);
  });

  return reminders;
}

