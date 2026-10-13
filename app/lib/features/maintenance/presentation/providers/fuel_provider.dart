import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/database/daos/fuel_log_dao.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/models/fuel_log_model.dart';
import '../../domain/calculators/fuel_economy.dart';
import '../../domain/entities/fuel_log.dart';

const _uuid = Uuid();
final _dao = FuelLogDao();

/// What the fill-up form hands over. Money is already completed: the form
/// derives whichever of total and price per litre the rider didn't type.
class FuelLogDraft {
  final DateTime filledAt;
  final double odometerKm;
  final double liters;
  final double totalCost;
  final double pricePerLiter;
  final bool fullTank;
  final String? station;
  final String? note;

  const FuelLogDraft({
    required this.filledAt,
    required this.odometerKm,
    required this.liters,
    required this.totalCost,
    required this.pricePerLiter,
    this.fullTank = true,
    this.station,
    this.note,
  });
}

/// One bike's fill-ups, newest first.
final fuelLogsProvider =
    AsyncNotifierProvider.family<FuelLogsNotifier, List<FuelLogEntity>, String>(
        FuelLogsNotifier.new);

class FuelLogsNotifier
    extends FamilyAsyncNotifier<List<FuelLogEntity>, String> {
  @override
  Future<List<FuelLogEntity>> build(String bikeId) async {
    final rows = await _dao.getForBike(bikeId);
    return rows.map(FuelLogModel.fromMap).toList();
  }

  /// Adds a fill-up, or rewrites [id] when editing. Returns its id.
  Future<String> save(FuelLogDraft d, {String? id}) async {
    final now = DateTime.now();
    final existing =
        id == null ? null : (await future).where((l) => l.id == id).firstOrNull;
    final entity = FuelLogEntity(
      id: id ?? _uuid.v4(),
      bikeId: arg,
      filledAt: d.filledAt,
      odometerKm: d.odometerKm,
      liters: d.liters,
      totalCost: d.totalCost,
      pricePerLiter: d.pricePerLiter,
      fullTank: d.fullTank,
      station: d.station,
      note: d.note,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final map = FuelLogModel.toMap(entity);
    await _dao.upsert(map);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      // The row is saved; a failed backup enqueue is a non-fatal (§101.R8)
      // and SyncManager uploads unsynced rows anyway.
      unawaited(ref
          .read(outboxServiceProvider)
          .enqueueFuelLog(uid: user.uid, logData: map)
          .catchError((Object e, StackTrace st) {
        reportNonFatal(e, st, reason: 'Fuel: outbox enqueue failed');
        return '';
      }));
    }
    _changed();
    return entity.id;
  }

  /// Deletes a fill-up. Tombstoned, so the cloud copy goes too.
  Future<void> delete(String id) async {
    await _dao
        .deleteWithTombstone([id], userId: ref.read(currentUserProvider)?.uid);
    _changed();
  }

  void _changed() {
    ref.invalidateSelf();
    ref.invalidate(userFuelLogsProvider);
  }
}

/// Headline numbers for one bike; null while loading.
final fuelSummaryProvider =
    Provider.family<FuelSummary?, String>((ref, bikeId) {
  final logs = ref.watch(fuelLogsProvider(bikeId)).valueOrNull;
  return logs == null ? null : summarizeFuel(logs);
});

/// Every fill-up on the rider's bikes, archived ones included, oldest
/// first — the Rides tab's fuel charts.
final userFuelLogsProvider = FutureProvider<List<FuelLogEntity>>((ref) async {
  ref.watch(garageProvider);
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const [];
  final rows = await _dao.getAllForUser(uid);
  return rows.map(FuelLogModel.fromMap).toList();
});
