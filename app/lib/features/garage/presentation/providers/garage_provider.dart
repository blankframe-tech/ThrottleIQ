import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/bike_entity.dart';
import '../../data/models/bike_model.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final _dao = BikeDao();
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
      createdAt: DateTime.now(),
    );
    await _dao.insert(BikeModel.toMap(bike));
    // If first bike, make it active
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) {
      await _dao.setActive(bike.id, uid);
    }
    ref.invalidateSelf();
    return bike.id;
  }

  /// Calibrates the bike's baseline odometer so `currentOdometerKm` matches
  /// the physical instrument cluster reading captured during sync.
  Future<void> syncOdometer({
    required String bikeId,
    required double newOdometerKm,
  }) async {
    final bikes = state.valueOrNull ?? [];
    final bike = bikes.where((b) => b.id == bikeId).firstOrNull;
    if (bike == null) return;
    final newBaseline = (newOdometerKm - bike.totalDistanceKm).clamp(0.0, double.infinity);
    await _dao.updateOdometer(bikeId, newBaseline);
    ref.invalidateSelf();
  }

  Future<void> updateBike(BikeEntity bike) async {
    await _dao.update(BikeModel.toMap(bike));
    ref.invalidateSelf();
  }

  /// Hard delete: the bike, its rides and their trails, here and (via the
  /// tombstone) in the cloud. Only for the explicit "delete bike and all its
  /// rides" action; [archiveBike] is the default.
  Future<void> deleteBike(String id) async {
    await _dao.delete(id);
    ref.invalidateSelf();
  }

  /// Retires a bike while keeping its rides, totals and maintenance history.
  Future<void> archiveBike(String id) async {
    await _dao.setArchived(id, true);
    ref.invalidateSelf();
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
