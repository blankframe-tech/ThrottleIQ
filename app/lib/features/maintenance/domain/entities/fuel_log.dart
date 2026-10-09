/// One fuel fill-up on one bike (schema v27, `fuel_logs`).
///
/// Money is in the app's currency (৳), volume in litres and distance in km,
/// whatever the rider typed them in. [pricePerLiter] and [totalCost] are both
/// stored: the rider enters one of them and the form derives the other, so
/// neither has to be recomputed (and rounded differently) on every read.
///
/// [fullTank] is what makes efficiency measurable: km/L is only known
/// between two fill-ups that each topped the tank off. See
/// `fuel_economy.dart`.
class FuelLogEntity {
  final String id;
  final String bikeId;
  final DateTime filledAt;
  final double odometerKm;
  final double liters;
  final double totalCost;
  final double pricePerLiter;
  final bool fullTank;
  final String? station;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FuelLogEntity({
    required this.id,
    required this.bikeId,
    required this.filledAt,
    required this.odometerKm,
    required this.liters,
    required this.totalCost,
    required this.pricePerLiter,
    this.fullTank = true,
    this.station,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  FuelLogEntity copyWith({
    DateTime? filledAt,
    double? odometerKm,
    double? liters,
    double? totalCost,
    double? pricePerLiter,
    bool? fullTank,
    String? station,
    String? note,
    DateTime? updatedAt,
  }) =>
      FuelLogEntity(
        id: id,
        bikeId: bikeId,
        filledAt: filledAt ?? this.filledAt,
        odometerKm: odometerKm ?? this.odometerKm,
        liters: liters ?? this.liters,
        totalCost: totalCost ?? this.totalCost,
        pricePerLiter: pricePerLiter ?? this.pricePerLiter,
        fullTank: fullTank ?? this.fullTank,
        station: station ?? this.station,
        note: note ?? this.note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is FuelLogEntity &&
      other.id == id &&
      other.bikeId == bikeId &&
      other.filledAt == filledAt &&
      other.odometerKm == odometerKm &&
      other.liters == liters &&
      other.totalCost == totalCost &&
      other.pricePerLiter == pricePerLiter &&
      other.fullTank == fullTank &&
      other.station == station &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, bikeId, filledAt, odometerKm, liters,
      totalCost, pricePerLiter, fullTank, station, note, createdAt, updatedAt);

  @override
  String toString() =>
      'FuelLog($id, $bikeId, $filledAt, ${odometerKm}km, ${liters}L, '
      '৳$totalCost, ${fullTank ? 'full' : 'partial'})';
}
