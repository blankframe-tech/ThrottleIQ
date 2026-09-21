import 'package:equatable/equatable.dart';

// Prefixed: the calculator function shares its name with the [jamSeconds]
// getter below, which would otherwise resolve to itself recursively.
import '../../../../core/utils/ride_speed_invariant.dart';
import '../calculators/jam_time.dart' as jam_time;
import 'bike_attribution.dart';

export 'bike_attribution.dart' show BikeAttributionConfidence;

enum RideStatus { active, paused, completed, crash }

class RideEntity extends Equatable {
  final String id;
  final String userId;
  final String bikeId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceM;
  final double? avgSpeedMs;
  final double? maxSpeedMs;
  final int? durationSeconds;

  /// Seconds spent above the moving threshold — see average_speed.dart. Null
  /// for rides finalized before this was tracked, or one still in progress.
  final int? movingSeconds;

  final int hardBrakeCount;
  final int rapidAccelCount;
  final int highJerkCount;
  final RideStatus status;
  final String? mapSnapshotPath;

  /// True when auto-tracking started this ride rather than the rider.
  ///
  /// Drives the "detected automatically" label in history, and is why
  /// [bikeConfidence] can be anything other than
  /// [BikeAttributionConfidence.high].
  final bool isAuto;

  /// How much to trust [bikeId] — see [BikeAttributionConfidence].
  final BikeAttributionConfidence bikeConfidence;

  /// The saved route the rider was following when this ride was recorded, or
  /// null for an ordinary ride (issues §78.21).
  ///
  /// [routeName] is stored alongside the id rather than looked up, for three
  /// reasons: a *discovered* route lives under another rider's uid, so the id
  /// alone can't find it; the route may be renamed or deleted afterwards, and
  /// history should still say what was ridden that day; and a ride row is read
  /// in list views where a per-row Firestore fetch would be absurd.
  final String? routeId;
  final String? routeName;

  const RideEntity({
    required this.id,
    required this.userId,
    required this.bikeId,
    required this.startTime,
    this.endTime,
    this.distanceM = 0,
    this.avgSpeedMs,
    this.maxSpeedMs,
    this.durationSeconds,
    this.movingSeconds,
    this.hardBrakeCount = 0,
    this.rapidAccelCount = 0,
    this.highJerkCount = 0,
    this.status = RideStatus.active,
    this.mapSnapshotPath,
    this.isAuto = false,
    this.bikeConfidence = BikeAttributionConfidence.high,
    this.routeId,
    this.routeName,
  });

  /// True when this ride was recorded while following a saved route.
  bool get followedRoute => routeId != null;

  double get distanceKm => distanceM / 1000;
  double get avgSpeedKmh => (avgSpeedMs ?? 0) * 3.6;
  double get maxSpeedKmh => RideSpeedInvariant.reconcile(
        avgSpeedKmh: avgSpeedKmh,
        rawMaxSpeedKmh: (maxSpeedMs ?? 0) * 3.6,
      );

  /// Seconds of this ride spent stopped in traffic while still recording —
  /// see jam_time.dart. Null rather than a guessed zero when either input is
  /// missing (an in-progress ride, or one finalized before moving time was
  /// tracked), so callers can tell "no jam time" apart from "unknown".
  int? get jamSeconds {
    final duration = durationSeconds;
    final moving = movingSeconds;
    if (duration == null || moving == null) return null;
    return jam_time.jamSeconds(durationSeconds: duration, movingSeconds: moving);
  }

  RideEntity copyWith({
    double? distanceM,
    double? avgSpeedMs,
    double? maxSpeedMs,
    int? durationSeconds,
    int? movingSeconds,
    int? hardBrakeCount,
    int? rapidAccelCount,
    int? highJerkCount,
    RideStatus? status,
    DateTime? endTime,
    String? mapSnapshotPath,
    bool? isAuto,
    BikeAttributionConfidence? bikeConfidence,
    String? bikeId,
    String? routeId,
    String? routeName,
  }) {
    return RideEntity(
      id: id,
      userId: userId,
      bikeId: bikeId ?? this.bikeId,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      distanceM: distanceM ?? this.distanceM,
      avgSpeedMs: avgSpeedMs ?? this.avgSpeedMs,
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      hardBrakeCount: hardBrakeCount ?? this.hardBrakeCount,
      rapidAccelCount: rapidAccelCount ?? this.rapidAccelCount,
      highJerkCount: highJerkCount ?? this.highJerkCount,
      status: status ?? this.status,
      mapSnapshotPath: mapSnapshotPath ?? this.mapSnapshotPath,
      isAuto: isAuto ?? this.isAuto,
      bikeConfidence: bikeConfidence ?? this.bikeConfidence,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, bikeId, startTime, status, isAuto, bikeConfidence, routeId];
}
