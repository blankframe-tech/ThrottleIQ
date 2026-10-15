import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_point_entity.dart';
import '../../domain/repositories/ride_repository.dart';
import '../models/ride_model.dart';

class RideRepositoryImpl implements RideRepository {
  final RideDao _rideDao;
  final RidePointDao _pointDao;

  RideRepositoryImpl({
    RideDao? rideDao,
    RidePointDao? pointDao,
  })  : _rideDao = rideDao ?? RideDao(),
        _pointDao = pointDao ?? RidePointDao();

  @override
  Future<void> saveRide(RideEntity ride) async {
    await _rideDao.insert(RideModel.toMap(ride));
  }

  @override
  Future<List<RideEntity>> getCompletedRidesForUser(String userId) async {
    final rows = await _rideDao.getAllForUser(userId);
    return rows.map((r) => RideModel.fromMap(r)).toList();
  }

  @override
  Future<List<RideEntity>> getCompletedRidesForBike(String bikeId) async {
    final rows = await _rideDao.getAllForBike(bikeId);
    return rows.map((r) => RideModel.fromMap(r)).toList();
  }

  @override
  Future<RideEntity?> getRideById(String id) async {
    final row = await _rideDao.getById(id);
    if (row == null) return null;
    return RideModel.fromMap(row);
  }

  @override
  Future<List<RidePointEntity>> getPointsForRide(String rideId) async {
    final rows = await _pointDao.getForRide(rideId);
    return rows.map((m) {
      return RidePointEntity(
        rideId: m['ride_id'] as String? ?? rideId,
        timestamp: DateTime.parse(m['timestamp'] as String),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        speedMs: (m['speed_ms'] as num?)?.toDouble() ?? 0.0,
        acceleration: (m['acceleration'] as num?)?.toDouble(),
        jerk: (m['jerk'] as num?)?.toDouble(),
        altitudeM: (m['altitude_m'] as num?)?.toDouble(),
        periodType: m['period_type'] as String? ?? 'moving',
        accuracyM: (m['accuracy_m'] as num?)?.toDouble(),
        headingDeg: (m['heading_deg'] as num?)?.toDouble(),
        confidence: m['confidence'] as int?,
        imuQuality: m['imu_quality'] as int?,
        isCornering: m['is_cornering'] == null ? null : (m['is_cornering'] as int) == 1,
      );
    }).toList();
  }

  @override
  Future<void> deleteRide(String id) async {
    await _rideDao.delete(id);
  }

  @override
  Future<void> deleteAllRidesForUser(String userId) async {
    await _rideDao.deleteAllForUser(userId);
  }
}
