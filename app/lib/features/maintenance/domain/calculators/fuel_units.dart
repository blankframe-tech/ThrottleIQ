/// Unit conversions for the running-cost settings. Everything is stored in
/// metric (৳/litre, km/litre); imperial riders type ৳/US gallon and mpg (US).
class FuelUnits {
  const FuelUnits._();

  static const double kmPerMile = 1.609344;
  static const double litresPerUsGallon = 3.785411784;

  static double mpgToKmPerLitre(double mpg) =>
      mpg * kmPerMile / litresPerUsGallon;
  static double kmPerLitreToMpg(double kmpl) =>
      kmpl * litresPerUsGallon / kmPerMile;

  static double pricePerGallonToPerLitre(double perGallon) =>
      perGallon / litresPerUsGallon;
  static double pricePerLitreToPerGallon(double perLitre) =>
      perLitre * litresPerUsGallon;

  /// ৳/km → ৳/mile.
  static double costPerKmToPerMile(double perKm) => perKm * kmPerMile;
}
