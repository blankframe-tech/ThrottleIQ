import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/daos/bike_running_cost_dao.dart';
import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/database/daos/maintenance_dao.dart';
import '../../../../core/database/daos/maintenance_config_dao.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/models/maintenance_model.dart';
import '../../data/models/maintenance_config_model.dart';
import '../../data/models/bike_running_cost_model.dart';
import '../../domain/calculators/ride_cost_calculator.dart';
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

  /// "Master service log" reset: logs each of [serviceTypes] as serviced
  /// now at [odometerKm], resetting its due-date countdown without
  /// touching prior history (mirrors what tapping "Log" does per item).
  Future<void> resetItems(
    List<ServiceType> serviceTypes, {
    required double odometerKm,
  }) async {
    if (serviceTypes.isEmpty) return;
    final bikeId = arg;
    final now = DateTime.now();
    final user = ref.read(currentUserProvider);
    final outbox = ref.read(outboxServiceProvider);
    for (final type in serviceTypes) {
      final log = MaintenanceEntity(
        id: _uuid.v4(),
        bikeId: bikeId,
        serviceType: type,
        date: now,
        odometerKm: odometerKm,
        createdAt: now,
      );
      final map = MaintenanceModel.toMap(log);
      await _dao.insert(map);
      if (user != null) {
        unawaited(outbox.enqueueMaintenanceLog(uid: user.uid, logData: map));
      }
    }
    ref.invalidateSelf();
    unawaited(HomeWidgetService.instance.refreshFromLocalData());
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
    _queueSettingsBackup(ref, bikeId);
    ref.invalidateSelf();
    ref.invalidate(isMaintenanceCustomizedProvider(bikeId));
    unawaited(HomeWidgetService.instance.refreshFromLocalData());
  }

  Future<void> updateSingleConfig(MaintenanceConfigEntity updated) async {
    // `future`, not `state.valueOrNull`: right after a save the notifier is
    // reloading and valueOrNull is the *previous* list, so a second edit
    // made before the reload finished silently reverted the first.
    final current = await future;
    final index =
        current.indexWhere((c) => c.serviceType == updated.serviceType);
    final List<MaintenanceConfigEntity> updatedList;
    if (index >= 0) {
      updatedList = List.of(current)..[index] = updated;
    } else {
      updatedList = [...current, updated];
    }
    await saveConfigs(updatedList);
  }
}

/// Backs a bike's maintenance settings up to the cloud after a local save
/// (issues §88.2). Fire-and-forget: the outbox has it on disk before this
/// returns, and delivery never blocks the settings UI.
void _queueSettingsBackup(Ref ref, String bikeId) {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  unawaited(ref
      .read(outboxServiceProvider)
      .enqueueMaintenanceSettings(uid: user.uid, bikeId: bikeId));
}

final maintenanceRemindersProvider =
    Provider.family<List<MaintenanceReminder>, String>((ref, bikeId) {
  final bike = ref.watch(garageProvider).valueOrNull?.where((b) => b.id == bikeId).firstOrNull;
  final logs = ref.watch(maintenanceProvider(bikeId)).valueOrNull ?? [];
  final configs = ref.watch(maintenanceConfigProvider(bikeId)).valueOrNull ?? [];
  if (bike == null) return [];
  return _computeReminders(bike.currentOdometerKm, logs, configs);
});

/// Pure reminder computation, exposed so the escalation thresholds can be
/// pinned by a test without a database or providers.
@visibleForTesting
List<MaintenanceReminder> computeMaintenanceReminders(double currentKm,
        List<MaintenanceEntity> logs, List<MaintenanceConfigEntity> configs) =>
    _computeReminders(currentKm, logs, configs);

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
      notes: config.notes,
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


// ── Running costs (per-ride cost estimate) ───────────────────────────────

final _runningCostDao = BikeRunningCostDao();

/// The bike's fuel price & mileage. Always resolves (an empty entity when
/// the rider never set them) so callers never special-case "no row".
final bikeRunningCostProvider = AsyncNotifierProvider.family<
    BikeRunningCostNotifier, BikeRunningCostEntity, String>(
  BikeRunningCostNotifier.new,
);

class BikeRunningCostNotifier
    extends FamilyAsyncNotifier<BikeRunningCostEntity, String> {
  @override
  Future<BikeRunningCostEntity> build(String bikeId) async {
    final row = await _runningCostDao.getForBike(bikeId);
    return row == null
        ? BikeRunningCostEntity(bikeId: bikeId)
        : BikeRunningCostModel.fromMap(row);
  }

  Future<void> save({double? fuelPricePerLitre, double? kmPerLitre}) async {
    final entity = BikeRunningCostEntity(
      bikeId: arg,
      fuelPricePerLitre: fuelPricePerLitre,
      kmPerLitre: kmPerLitre,
    );
    await _runningCostDao.upsert(BikeRunningCostModel.toMap(entity));
    _queueSettingsBackup(ref, arg);
    state = AsyncData(entity);
  }
}

/// Running-cost breakdown for [distanceKm] on a bike, combining its tracked
/// checks, logged service costs and fuel settings. Null until all three
/// sources have loaded, so a card never flashes a partial total.
final rideCostProvider = Provider.family<RideCostBreakdown?,
    ({String bikeId, double distanceKm})>((ref, key) {
  final configs = ref.watch(maintenanceConfigProvider(key.bikeId)).valueOrNull;
  final logs = ref.watch(maintenanceProvider(key.bikeId)).valueOrNull;
  final running = ref.watch(bikeRunningCostProvider(key.bikeId)).valueOrNull;
  if (configs == null || logs == null || running == null) return null;
  return RideCostCalculator.compute(
    distanceKm: key.distanceKm,
    configs: configs,
    logs: logs,
    runningCost: running,
  );
});

// ── Distance unit on the maintenance page ────────────────────────────────

const _imperialPrefKey = 'maintenance_imperial_units';

/// km vs mi for the maintenance page, remembered across launches (it used
/// to reset to km every time the screen was opened).
final maintenanceImperialProvider =
    StateNotifierProvider<MaintenanceImperialNotifier, bool>(
  (ref) => MaintenanceImperialNotifier(),
);

class MaintenanceImperialNotifier extends StateNotifier<bool> {
  MaintenanceImperialNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_imperialPrefKey);
      if (v != null && mounted) state = v;
    } catch (_) {
      // Preferences unavailable (tests, platform hiccup) — stay on km.
    }
  }

  Future<void> set(bool imperial) async {
    state = imperial;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_imperialPrefKey, imperial);
    } catch (_) {}
  }
}
