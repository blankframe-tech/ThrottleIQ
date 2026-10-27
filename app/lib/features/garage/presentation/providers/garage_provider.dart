import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/bike_entity.dart';
import '../../data/models/bike_model.dart';
import '../../data/bike_archive_service.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final _dao = BikeDao();

final bikeArchiveServiceProvider =
    Provider<BikeArchiveService>((ref) => BikeArchiveService());
const _uuid = Uuid();

/// The rider's garage: every bike they still ride. Archived bikes are left
/// out, so the garage list and every bike picker built on this hide them
/// without each needing its own filter. Screens that must resolve a ride's
/// bike whatever its state (stats, sharing) use [allBikesProvider].
final garageProvider =
    AsyncNotifierProvider<GarageNotifier, List<BikeEntity>>(GarageNotifier.new);

class GarageNotifier extends AsyncNotifier<List<BikeEntity>> {
  @override
  Future<List<BikeEntity>> build() async {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) return [];
    final rows = await _dao.getAllForUser(uid);
    return rows.map(BikeModel.fromMap).toList();
  }

  Future<String?> addBike({
    required String brand,
    required String model,
    int? year,
    int? cc,
    String? imagePath,
    double? odometerKm,
    int? colorValue,
    bool isEbike = false,
  }) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return null;
    final bike = BikeEntity(
      id: _uuid.v4(),
      userId: uid,
      brand: brand,
      model: model,
      year: year,
      cc: cc,
      imagePath: imagePath,
      odometerKm: odometerKm,
      colorValue: colorValue,
      isEbike: isEbike,
      createdAt: DateTime.now(),
    );
    await _dao.insert(BikeModel.toMap(bike));
    // Decide from the database, not provider state: while the garage is
    // loading (or errored) `state` is empty and would force the new bike
    // active over the rider's real one (issues §101.R10).
    final rows = await _dao.getAllForUser(uid);
    if (!rows.any((r) => r['is_active'] == 1)) {
      await _dao.setActive(bike.id, uid);
    }
    ref.invalidateSelf();
    return bike.id;
  }

  /// Calibrates the bike's baseline odometer so `currentOdometerKm` matches
  /// the physical instrument cluster reading captured during sync.
  ///
  /// Returns the odometer the bike actually shows afterwards. That is the
  /// entered reading unless it is below the GPS-tracked total, in which case
  /// the baseline is floored at 0 and the tracked total wins (§101.R7).
  /// Null when the bike isn't found.
  ///
  /// Reads the tracked km from the row, not the garage list cached when the
  /// sheet opened: km credited meanwhile would otherwise be counted twice
  /// (same class as [updateBike], critique oct27 #7).
  Future<double?> syncOdometer({
    required String bikeId,
    required double newOdometerKm,
  }) async {
    final row = await _dao.getById(bikeId);
    if (row == null) return null;
    final trackedKm = BikeModel.fromMap(row).totalDistanceKm;
    final newBaseline = (newOdometerKm - trackedKm).clamp(0.0, double.infinity);
    await _dao.updateOdometer(bikeId, newBaseline);
    ref.invalidateSelf();
    return newBaseline + trackedKm;
  }

  /// Saves the Edit Bike form. Writes only the columns the form edits: the
  /// [bike] it holds was loaded when the screen opened, and writing it whole
  /// undid km, ride counts and the active flag changed meanwhile, e.g. by
  /// auto-tracking credit (critique oct27 #7). [odometerReadingKm] is the
  /// dashboard reading the rider typed (null = untouched, baseline kept),
  /// turned into a baseline against the bike's tracked km as stored now.
  Future<void> updateBike(BikeEntity bike,
      {double? odometerReadingKm, bool clearOdometer = false}) async {
    final row = await _dao.getById(bike.id);
    if (row == null) return;
    final trackedKm = BikeModel.fromMap(row).totalDistanceKm;
    await _dao.update({
      'id': bike.id,
      'brand': bike.brand,
      'model': bike.model,
      'year': bike.year,
      'cc': bike.cc,
      'image_path': bike.imagePath,
      'color_value': bike.colorValue,
      'is_ebike': bike.isEbike ? 1 : 0,
      if (clearOdometer)
        'odometer_km': null
      else if (odometerReadingKm != null)
        'odometer_km':
            (odometerReadingKm - trackedKm).clamp(0.0, double.infinity),
      // The touch trigger stamps updated_at for last-writer-wins (C4).
      'synced': 0,
    });
    ref.invalidateSelf();
  }

  /// Hard delete: the bike, its rides and their trails, here and (via the
  /// tombstone) in the cloud. Only for the explicit "delete bike and all its
  /// rides" action; [archiveBike] is the default.
  Future<void> deleteBike(String id) async {
    await _dao.delete(id);
    ref.invalidateSelf();
  }

  /// Retires a bike. By default its rides, totals, service logs and photos
  /// are kept; [cleanup] removes the parts the rider picked. The bike is
  /// permanently deleted [kArchiveRetention] later (see [BikeArchiveService]).
  Future<void> archiveBike(
    BikeEntity bike, {
    ArchiveCleanup cleanup = const ArchiveCleanup(),
  }) async {
    await ref.read(bikeArchiveServiceProvider).archive(bike, cleanup);
    ref.invalidateSelf();
    ref.invalidate(allBikesProvider);
  }

  /// "Delete now" for an archived bike: skips the rest of the retention.
  Future<void> deleteArchivedNow(BikeEntity bike) async {
    await ref.read(bikeArchiveServiceProvider).deleteNow(bike);
    ref.invalidateSelf();
    ref.invalidate(allBikesProvider);
  }

  Future<void> unarchiveBike(String id) async {
    await _dao.setArchived(id, false);
    ref.invalidateSelf();
  }

  Future<void> setActiveBike(String id) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    await _dao.setActive(id, uid);
    ref.invalidateSelf();
  }

  BikeEntity? get activeBike {
    return state.valueOrNull?.where((b) => b.isActive).firstOrNull;
  }
}

final activeBikeProvider = Provider<BikeEntity?>((ref) {
  final bikes = ref.watch(garageProvider).valueOrNull ?? [];
  return bikes.where((b) => b.isActive).firstOrNull;
});

/// Every bike the rider has, archived ones included. For resolving a ride's
/// bike (a ride on an archived bike is still a ride) and for totals that
/// should not change just because a bike was retired.
///
/// Watches [garageProvider] only to rebuild whenever the garage changes —
/// archive/unarchive/edit all invalidate it.
final allBikesProvider = FutureProvider<List<BikeEntity>>((ref) async {
  ref.watch(garageProvider);
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return [];
  final rows = await _dao.getAllForUser(uid, includeArchived: true);
  return rows.map(BikeModel.fromMap).toList();
});

/// The "Archived bikes" section of the garage.
final archivedBikesProvider = Provider<List<BikeEntity>>((ref) {
  final bikes = ref.watch(allBikesProvider).valueOrNull ?? const [];
  return bikes.where((b) => b.isArchived).toList();
});
