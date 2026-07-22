import 'package:equatable/equatable.dart';

class BikeEntity extends Equatable {
  final String id;
  final String userId;
  final String brand;
  final String model;
  final int? year;
  final int? cc;
  final String? imagePath;
  final bool isActive;
  final double totalDistanceM;
  final int rideCount;
  final DateTime? lastRideAt;

  /// Optional real-world odometer reading captured when the bike was added
  /// (or edited) — a baseline the app can't derive from GPS alone (rides
  /// before the bike was added to the app, odometer drift, etc.).
  final double? odometerKm;

  final DateTime createdAt;

  const BikeEntity({
    required this.id,
    required this.userId,
    required this.brand,
    required this.model,
    this.year,
    this.cc,
    this.imagePath,
    this.isActive = false,
    this.totalDistanceM = 0,
    this.rideCount = 0,
    this.lastRideAt,
    this.odometerKm,
    required this.createdAt,
  });

  double get totalDistanceKm => totalDistanceM / 1000;

  /// The bike's best-known current mileage: the manually-entered baseline
  /// plus everything GPS-tracked since. Falls back to just the GPS total
  /// when no baseline was ever set.
  double get currentOdometerKm => (odometerKm ?? 0) + totalDistanceKm;

  String get displayName => '$brand $model${year != null ? ' ($year)' : ''}';

  BikeEntity copyWith({
    String? brand,
    String? model,
    int? year,
    int? cc,
    String? imagePath,
    bool? isActive,
    double? totalDistanceM,
    int? rideCount,
    DateTime? lastRideAt,
    double? odometerKm,
  }) {
    return BikeEntity(
      id: id,
      userId: userId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      cc: cc ?? this.cc,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      totalDistanceM: totalDistanceM ?? this.totalDistanceM,
      rideCount: rideCount ?? this.rideCount,
      lastRideAt: lastRideAt ?? this.lastRideAt,
      odometerKm: odometerKm ?? this.odometerKm,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, brand, model, year, cc, imagePath, isActive, odometerKm];
}
