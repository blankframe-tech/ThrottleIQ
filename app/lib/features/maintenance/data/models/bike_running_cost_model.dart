import '../../domain/entities/maintenance_entity.dart';

class BikeRunningCostModel {
  static BikeRunningCostEntity fromMap(Map<String, dynamic> m) =>
      BikeRunningCostEntity(
        bikeId: m['bike_id'] as String,
        fuelPricePerLitre: (m['fuel_price_per_litre'] as num?)?.toDouble(),
        kmPerLitre: (m['km_per_litre'] as num?)?.toDouble(),
      );

  static Map<String, dynamic> toMap(BikeRunningCostEntity e) => {
        'bike_id': e.bikeId,
        'fuel_price_per_litre': _positiveOrNull(e.fuelPricePerLitre),
        'km_per_litre': _positiveOrNull(e.kmPerLitre),
      };

  static double? _positiveOrNull(double? v) => (v != null && v > 0) ? v : null;
}
