import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/database/daos/bike_running_cost_dao.dart';
import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/database/daos/maintenance_dao.dart';
import '../../../../core/database/daos/maintenance_config_dao.dart';
import '../../../../core/database/daos/maintenance_profile_dao.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/data/models/bike_model.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/models/maintenance_model.dart';
import '../../data/models/maintenance_config_model.dart';
import '../../data/models/bike_running_cost_model.dart';
import '../../data/repositories/maintenance_forecast_repository.dart';
import '../../data/repositories/maintenance_usage_repository.dart';
import '../../data/services/maintenance_alerts.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/calculators/maintenance_money.dart';
import '../../domain/calculators/ride_cost_calculator.dart';
import '../../domain/calculators/riding_conditions.dart';
import '../../domain/catalog/schedule_templates.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/maintenance_profile.dart';
import '../../domain/entities/service_visit.dart';

const _uuid = Uuid();
final _dao = MaintenanceDao();

/// After any maintenance change: the home-screen widget and notifications
/// re-read the same engine. Fire-and-forget; both are no-op safe.
void _afterMaintenanceChange() {
  unawaited(HomeWidgetService.instance.refreshFromLocalData());
  MaintenanceAlerts.instance.scheduleEvaluate();
}

// ── Service logs & visits ────────────────────────────────────────────────

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

  /// A single item, logged as a visit of one.
  Future<void> addLog({
    required String bikeId,
    required ServiceType serviceType,
    required DateTime date,
    required double odometerKm,
    double? cost,
    String? notes,
    String? customLabel,
  }) async {
    await saveVisit(VisitDraft(
      date: date,
      odometerKm: odometerKm,
      totalCost: cost,
      notes: notes,
      items: [VisitItemDraft(type: serviceType, customLabel: customLabel)],
    ));
  }

  /// Logs a whole visit — every ticked item in one go. Returns the visit id
  /// (for Undo).
  Future<String> saveVisit(VisitDraft draft) async {
    final visitId = _uuid.v4();
    final rows = buildVisitLogs(
      bikeId: arg,
      visitId: visitId,
      draft: draft,
      newId: _uuid.v4,
      now: DateTime.now(),
    );
    await _persist(rows);
    return visitId;
  }

  /// Rewrites visit [visitKey] from [draft]: kept items are updated in place,
  /// new ones added, unticked ones deleted (with tombstones).
  Future<void> updateVisit(String visitKey, VisitDraft draft) async {
    final current = await future;
    final existing = current.where((l) => l.visitKey == visitKey).toList();
    final rows = buildVisitLogs(
      bikeId: arg,
      visitId: visitKey,
      draft: draft,
      newId: _uuid.v4,
      now: DateTime.now(),
      existing: existing,
    );
    final keptIds = rows.map((r) => r.id).toSet();
    final removed =
        existing.where((e) => !keptIds.contains(e.id)).map((e) => e.id).toList();
    await _dao.deleteWithTombstone(removed,
        userId: ref.read(currentUserProvider)?.uid);
    await _persist(rows);
  }

  /// Deletes every item of a visit. Tombstoned, so the cloud copies are
  /// removed too and never come back (§94.2).
  Future<void> deleteVisit(String visitKey) async {
    final current = await future;
    final ids = current
        .where((l) => l.visitKey == visitKey)
        .map((l) => l.id)
        .toList();
    await _dao.deleteWithTombstone(ids,
        userId: ref.read(currentUserProvider)?.uid);
    ref.invalidateSelf();
    _afterMaintenanceChange();
  }

  Future<void> deleteLog(String id) async {
    await _dao.deleteWithTombstone([id],
        userId: ref.read(currentUserProvider)?.uid);
    ref.invalidateSelf();
    _afterMaintenanceChange();
  }

  /// "Master service log" reset: logs [serviceTypes] as serviced now at
  /// [odometerKm] — one visit, resetting each due date while keeping prior
  /// history.
  Future<void> resetItems(
    List<ServiceType> serviceTypes, {
    required double odometerKm,
  }) async {
    if (serviceTypes.isEmpty) return;
    await saveVisit(VisitDraft(
      date: DateTime.now(),
      odometerKm: odometerKm,
      items: [for (final t in serviceTypes) VisitItemDraft(type: t)],
    ));
  }

  Future<void> _persist(List<MaintenanceEntity> rows) async {
    final maps = rows.map(MaintenanceModel.toMap).toList();
    await _dao.insertAll(maps);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final outbox = ref.read(outboxServiceProvider);
      for (final map in maps) {
        unawaited(outbox.enqueueMaintenanceLog(uid: user.uid, logData: map));
      }
    }
    ref.invalidateSelf();
    _afterMaintenanceChange();
  }
}

// ── Tracked checks ───────────────────────────────────────────────────────

final _configDao = MaintenanceConfigDao();
final _profileDao = MaintenanceProfileDao();

final isMaintenanceCustomizedProvider =
    FutureProvider.family<bool, String>((ref, bikeId) async {
  return _configDao.hasCustomized(bikeId);
});

Future<BikeEntity?> _bikeById(String bikeId) async {
  final row = await BikeDao().getById(bikeId);
  return row == null ? null : BikeModel.fromMap(row);
}

final maintenanceConfigProvider = AsyncNotifierProvider.family<
    MaintenanceConfigNotifier, List<MaintenanceConfigEntity>, String>(
  MaintenanceConfigNotifier.new,
);

class MaintenanceConfigNotifier
    extends FamilyAsyncNotifier<List<MaintenanceConfigEntity>, String> {
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async {
    final profile = await ref.watch(maintenanceProfileProvider(bikeId).future);
    final bike = await _bikeById(bikeId);
    final defaults = bike != null
        ? defaultConfigsFor(bike, profile)
        : configsFromTemplate(
            bikeId: bikeId, template: templateById(profile?.templateId));

    final rows = await _configDao.getConfigsForBike(bikeId);
    if (rows.isEmpty) return defaults;

    final saved = rows.map(MaintenanceConfigModel.fromMap).toList();
    final existingKeys = saved.map((c) => c.key).toSet();
    return [
      ...saved,
      // Types added to the catalogue after the rider customised: listed,
      // off.
      for (final d in defaults)
        if (!existingKeys.contains(d.key)) d.copyWith(isEnabled: false),
    ];
  }

  Future<void> saveConfigs(List<MaintenanceConfigEntity> configs) async {
    final bikeId = arg;
    final maps = configs.map(MaintenanceConfigModel.toMap).toList();
    await _configDao.saveConfigsForBike(bikeId, maps);
    queueMaintenanceSettingsBackup(ref, bikeId);
    ref.invalidateSelf();
    ref.invalidate(isMaintenanceCustomizedProvider(bikeId));
    _afterMaintenanceChange();
  }

  Future<void> updateSingleConfig(MaintenanceConfigEntity updated) async {
    // `future`, not `state.valueOrNull`: right after a save the notifier is
    // reloading and valueOrNull is the *previous* list, so a second edit
    // made before the reload finished silently reverted the first.
    final current = await future;
    final index = current.indexWhere((c) => c.key == updated.key);
    final List<MaintenanceConfigEntity> updatedList;
    if (index >= 0) {
      updatedList = List.of(current)..[index] = updated;
    } else {
      updatedList = [...current, updated];
    }
    await saveConfigs(updatedList);
  }

  /// A rider-defined check with its own interval and reminders.
  Future<void> addCustomCheck({
    required String label,
    required double intervalKm,
    int? intervalDays,
  }) async {
    final current = await future;
    await saveConfigs([
      ...current,
      MaintenanceConfigEntity(
        bikeId: arg,
        serviceType: ServiceType.custom,
        customId: _uuid.v4(),
        customLabel: label.trim(),
        intervalKm: intervalKm,
        intervalDays: intervalDays,
        source: IntervalSource.user,
      ),
    ]);
  }

  Future<void> removeCustomCheck(String key) async {
    final current = await future;
    await saveConfigs(current.where((c) => c.key != key).toList());
  }

  /// "Set last done" for a check with no log: where it counts from.
  Future<void> setBaseline(String key,
      {required double? km, required DateTime? date}) async {
    final current = await future;
    final c = current.where((c) => c.key == key).firstOrNull;
    if (c == null) return;
    await updateSingleConfig(MaintenanceConfigEntity(
      bikeId: c.bikeId,
      serviceType: c.serviceType,
      intervalKm: c.intervalKm,
      intervalDays: c.intervalDays,
      isEnabled: c.isEnabled,
      notes: c.notes,
      typicalCost: c.typicalCost,
      warnKm: c.warnKm,
      warnDays: c.warnDays,
      baselineKm: km,
      baselineDate: date,
      source: c.source,
      customId: c.customId,
      customLabel: c.customLabel,
    ));
  }
}

/// Backs a bike's maintenance settings up to the cloud after a local save
/// (issues §88.2). Fire-and-forget: the outbox has it on disk before this
/// returns, and delivery never blocks the settings UI.
void queueMaintenanceSettingsBackup(Ref ref, String bikeId) {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  unawaited(ref
      .read(outboxServiceProvider)
      .enqueueMaintenanceSettings(uid: user.uid, bikeId: bikeId));
}

// ── Setup profile ────────────────────────────────────────────────────────

/// What the rider answers in setup.
class MaintenanceSetupDraft {
  final ScheduleTemplate template;
  final RidingProfile ridingProfile;
  final OilGrade? oilGrade;
  final double? lastOilKm;
  final DateTime? lastOilDate;

  /// "Everything else was done at that service too."
  final bool othersAtSameService;

  /// Replace every interval with the template's, including hand-edited ones.
  final bool resetIntervals;

  const MaintenanceSetupDraft({
    required this.template,
    this.ridingProfile = RidingProfile.normal,
    this.oilGrade,
    this.lastOilKm,
    this.lastOilDate,
    this.othersAtSameService = false,
    this.resetIntervals = false,
  });
}

final maintenanceProfileProvider = AsyncNotifierProvider.family<
    MaintenanceProfileNotifier, MaintenanceProfileEntity?, String>(
  MaintenanceProfileNotifier.new,
);

class MaintenanceProfileNotifier
    extends FamilyAsyncNotifier<MaintenanceProfileEntity?, String> {
  @override
  Future<MaintenanceProfileEntity?> build(String bikeId) async {
    final row = await _profileDao.getProfile(bikeId);
    return row == null ? null : MaintenanceProfileEntity.fromMap(row);
  }

  Future<void> _save(MaintenanceProfileEntity p) async {
    await _profileDao.upsertProfile(p.toMap());
    queueMaintenanceSettingsBackup(ref, arg);
    state = AsyncData(p);
  }

  Future<MaintenanceProfileEntity> _current() async {
    final existing = await future;
    if (existing != null) return existing;
    final bike = await _bikeById(arg);
    return MaintenanceProfileEntity(
      bikeId: arg,
      templateId: bike == null
          ? kDefaultTemplateId
          : suggestTemplate(brand: bike.brand, model: bike.model, cc: bike.cc)
              .id,
    );
  }

  /// Makes sure the bike has a profile row (not yet onboarded) — paperwork
  /// and quick checks hang off it, and it's what carries them in the cloud
  /// backup.
  Future<void> ensureProfile() async {
    if (await future != null) return;
    await _save(await _current());
  }

  /// Writes the setup answers: the profile, the template's checks, and the
  /// baselines the rider gave.
  Future<void> completeSetup(MaintenanceSetupDraft d) async {
    final configNotifier = ref.read(maintenanceConfigProvider(arg).notifier);
    final customized = await _configDao.hasCustomized(arg);
    final current = await ref.read(maintenanceConfigProvider(arg).future);

    var configs = (!customized || d.resetIntervals)
        ? [
            ...configsFromTemplate(
                bikeId: arg, template: d.template, oilGrade: d.oilGrade),
            // Custom checks survive a reset — they aren't the template's.
            ...current.where((c) => c.isCustom),
          ]
        : retuneToTemplate(
            current: current, template: d.template, oilGrade: d.oilGrade);

    if (d.lastOilKm != null || d.lastOilDate != null) {
      configs = [
        for (final c in configs)
          (c.serviceType == ServiceType.oilChange ||
                  (d.othersAtSameService && c.isEnabled && !c.isCustom))
              ? c.copyWith(baselineKm: d.lastOilKm, baselineDate: d.lastOilDate)
              : c,
      ];
    }

    // Checks before the profile: the config notifier watches the profile,
    // so saving the profile first would leave it mid-rebuild when asked to
    // save.
    await configNotifier.saveConfigs(configs);
    final existing = await future;
    await _save(MaintenanceProfileEntity(
      bikeId: arg,
      templateId: d.template.id,
      ridingProfile: d.ridingProfile,
      oilGrade: d.oilGrade,
      adaptIntervals: existing?.adaptIntervals ?? true,
      onboardedAt: DateTime.now(),
      lastPrecheckAt: existing?.lastPrecheckAt,
    ));
  }

  Future<void> setAdaptIntervals(bool on) async {
    await _save((await _current()).copyWith(adaptIntervals: on));
    _afterMaintenanceChange();
  }

  Future<void> setRidingProfile(RidingProfile p) async {
    await _save((await _current()).copyWith(ridingProfile: p));
    _afterMaintenanceChange();
  }

  /// The oil just put in decides the next oil change. Retunes the oil check
  /// unless the rider set its interval by hand.
  Future<void> applyOilGrade(OilGrade grade) async {
    final p = await _current();
    // The check first, then the profile — see completeSetup.
    final configs = await ref.read(maintenanceConfigProvider(arg).future);
    final oil = configs
        .where((c) => c.serviceType == ServiceType.oilChange && !c.isCustom)
        .firstOrNull;
    final s = grade.schedule;
    if (oil != null &&
        oil.source != IntervalSource.user &&
        (oil.intervalKm != s.km || oil.intervalDays != s.days)) {
      await ref.read(maintenanceConfigProvider(arg).notifier).updateSingleConfig(
          oil.copyWith(intervalKm: s.km, intervalDays: s.days));
    }
    if (p.oilGrade != grade) await _save(p.copyWith(oilGrade: grade));
  }

  Future<void> markPrecheck(DateTime at) async {
    final p = await future;
    if (p == null) return;
    state = AsyncData(p.copyWith(lastPrecheckAt: at));
  }
}

// ── Riding pace & conditions ─────────────────────────────────────────────

class BikeUsage {
  final UsageStats usage;
  final double creditedKm;
  const BikeUsage(this.usage, this.creditedKm);
}

final _usageRepo = MaintenanceUsageRepository();

/// Recent riding for a bike. Re-read whenever the garage changes, which is
/// what a finished ride (or a detected-trip credit) does.
final bikeUsageProvider =
    FutureProvider.family<BikeUsage, String>((ref, bikeId) async {
  ref.watch(garageProvider);
  return BikeUsage(
    await _usageRepo.usageFor(bikeId),
    await MaintenanceForecastRepository.creditedKmFor(bikeId),
  );
});

// ── The forecast ─────────────────────────────────────────────────────────

/// Every enabled check's forecast, most urgent first. Empty until the bike,
/// its logs and its checks have loaded.
final maintenanceForecastProvider =
    Provider.family<List<CheckForecast>, String>((ref, bikeId) {
  final bike = ref
      .watch(garageProvider)
      .valueOrNull
      ?.where((b) => b.id == bikeId)
      .firstOrNull;
  final logs = ref.watch(maintenanceProvider(bikeId)).valueOrNull;
  final configs = ref.watch(maintenanceConfigProvider(bikeId)).valueOrNull;
  final profile = ref.watch(maintenanceProfileProvider(bikeId)).valueOrNull;
  final usage = ref.watch(bikeUsageProvider(bikeId)).valueOrNull;
  if (bike == null || logs == null || configs == null) return const [];
  return forecastChecks(
    configs: configs,
    logs: logs,
    input: buildForecastInput(
      bike: bike,
      profile: profile,
      usage: usage?.usage ?? UsageStats.empty,
      creditedKm: usage?.creditedKm ?? 0,
      now: DateTime.now(),
    ),
  );
});

/// The headline item for a bike, or null.
final maintenanceUpNextProvider =
    Provider.family<CheckForecast?, String>((ref, bikeId) {
  return upNext(ref.watch(maintenanceForecastProvider(bikeId)));
});

// ── Paperwork ────────────────────────────────────────────────────────────

final paperworkProvider = AsyncNotifierProvider.family<PaperworkNotifier,
    List<PaperworkEntity>, String>(PaperworkNotifier.new);

class PaperworkNotifier
    extends FamilyAsyncNotifier<List<PaperworkEntity>, String> {
  @override
  Future<List<PaperworkEntity>> build(String bikeId) async {
    final rows = await _profileDao.getPaperwork(bikeId);
    return rows.map(PaperworkEntity.fromMap).whereType<PaperworkEntity>().toList();
  }

  Future<void> upsert(PaperworkEntity p) async {
    await ref.read(maintenanceProfileProvider(arg).notifier).ensureProfile();
    await _profileDao.upsertPaperwork(p.toMap());
    queueMaintenanceSettingsBackup(ref, arg);
    ref.invalidateSelf();
    MaintenanceAlerts.instance.scheduleEvaluate();
  }

  Future<void> remove(PaperworkKind kind) async {
    await _profileDao.deletePaperwork(arg, kind.name);
    queueMaintenanceSettingsBackup(ref, arg);
    ref.invalidateSelf();
    MaintenanceAlerts.instance.scheduleEvaluate();
  }
}

// ── Pre-ride quick check ─────────────────────────────────────────────────

final precheckIssuesProvider = AsyncNotifierProvider.family<
    PrecheckIssuesNotifier, List<PrecheckIssue>, String>(
  PrecheckIssuesNotifier.new,
);

class PrecheckIssuesNotifier
    extends FamilyAsyncNotifier<List<PrecheckIssue>, String> {
  @override
  Future<List<PrecheckIssue>> build(String bikeId) async {
    final rows = await _profileDao.openPrecheckIssues(bikeId);
    return rows.map(PrecheckIssue.fromMap).whereType<PrecheckIssue>().toList();
  }

  Future<void> record(List<PrecheckItem> failed) async {
    final now = DateTime.now();
    await ref.read(maintenanceProfileProvider(arg).notifier).ensureProfile();
    await _profileDao.recordPrecheck(
      bikeId: arg,
      failedItems: failed.map((f) => f.name).toList(),
      at: now,
      newId: _uuid.v4,
    );
    await ref.read(maintenanceProfileProvider(arg).notifier).markPrecheck(now);
    ref.invalidateSelf();
  }

  Future<void> resolve(String id) async {
    await _profileDao.resolvePrecheckIssue(id, DateTime.now());
    ref.invalidateSelf();
  }
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
    queueMaintenanceSettingsBackup(ref, arg);
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

/// Spend per month and per km for the Money card.
final maintenanceMoneyProvider =
    FutureProvider.family<MaintenanceMoney, String>((ref, bikeId) async {
  // Every watch before the first await.
  ref.watch(garageProvider);
  final logsF = ref.watch(maintenanceProvider(bikeId).future);
  final runningF = ref.watch(bikeRunningCostProvider(bikeId).future);
  final logs = await logsF;
  final running = await runningF;
  final now = DateTime.now();
  final distance = await _usageRepo.distanceKmSince(
      bikeId, now.subtract(const Duration(days: 365)));
  return computeMoney(
    logs: logs,
    now: now,
    distanceKm12m: distance,
    fuelPricePerLitre: running.fuelPricePerLitre,
    kmPerLitre: running.kmPerLitre,
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
