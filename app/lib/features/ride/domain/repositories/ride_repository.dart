import '../entities/ride_entity.dart';
import '../entities/ride_point_entity.dart';

/// Abstract domain repository for ride querying and persistence.
///
/// Decouples presentation screens and providers from direct DAO / SQLite calls.
abstract class RideRepository {
  /// Inserts or updates a ride.
  Future<void> saveRide(RideEntity ride);

  /// Retrieves all completed rides for a user, sorted descending by start time.
  Future<List<RideEntity>> getCompletedRidesForUser(String userId);

  /// Retrieves all completed rides for a bike.
  Future<List<RideEntity>> getCompletedRidesForBike(String bikeId);

  /// Retrieves a single ride by its id.
  Future<RideEntity?> getRideById(String id);

  /// Retrieves recorded GPS trail points for a ride.
  Future<List<RidePointEntity>> getPointsForRide(String rideId);

  /// Deletes a ride and its trail points.
  Future<void> deleteRide(String id);

  /// Deletes all rides and points belonging to [userId].
  Future<void> deleteAllRidesForUser(String userId);
}
