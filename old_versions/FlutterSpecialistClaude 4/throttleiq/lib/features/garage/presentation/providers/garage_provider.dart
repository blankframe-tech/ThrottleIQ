import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/bike_entity.dart';
import '../../data/models/bike_model.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final _dao = BikeDao();
const _uuid = Uuid();

final garageProvider = AsyncNotifierProvider<GarageNotifier, List<BikeEntity>>(GarageNotifier.new);

class GarageNotifier extends AsyncNotifier<List<BikeEntity>> {
  @override
  Future<List<BikeEntity>> build() async {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) return [];
    final rows = await _dao.getAllForUser(uid);
    return rows.map(BikeModel.fromMap).toList();
  }

  Future<void> addBike({
    required String brand,
    required String model,
    int? year,
    int? cc,
    String? imagePath,
  }) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final bike = BikeEntity(
      id: _uuid.v4(),
      userId: uid,
      brand: brand,
      model: model,
      year: year,
      cc: cc,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );
    await _dao.insert(BikeModel.toMap(bike));
    // If first bike, make it active
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) {
      await _dao.setActive(bike.id, uid);
    }
    ref.invalidateSelf();
  }

  Future<void> updateBike(BikeEntity bike) async {
    await _dao.update(BikeModel.toMap(bike));
    ref.invalidateSelf();
  }

  Future<void> deleteBike(String id) async {
    await _dao.delete(id);
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
