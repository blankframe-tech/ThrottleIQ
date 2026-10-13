import 'entities/place_entity.dart';

/// Rider-facing facts about a place that a category alone doesn't say —
/// "is this pump open at 2am", "can this garage read an EFI fault code".
///
/// Stored on the place doc as a list of [name]s (`tags`), so adding a value
/// here never needs a migration, and an unknown name written by a newer
/// build is simply dropped on read by [PlaceTag.parseAll] instead of
/// crashing an older one.
enum PlaceTag {
  open24h,
  octane95,
  digitalPayment,
  efiDiagnostics,
  punctureRepair,
  paddockStand,
  genuineParts,
  bikeParking,
  restrooms;

  /// Categories this tag makes sense for. The add-place form only offers a
  /// tag for these, and the filter sheet only shows the ones relevant to the
  /// selected category, so nobody tags a speed camera "95 octane".
  Set<PlaceCategory> get categories => switch (this) {
        PlaceTag.open24h => const {
            PlaceCategory.fuel,
            PlaceCategory.garage,
            PlaceCategory.parts,
            PlaceCategory.recreation,
          },
        PlaceTag.octane95 => const {PlaceCategory.fuel},
        PlaceTag.digitalPayment => const {
            PlaceCategory.fuel,
            PlaceCategory.garage,
            PlaceCategory.parts,
            PlaceCategory.recreation,
          },
        PlaceTag.efiDiagnostics => const {PlaceCategory.garage},
        PlaceTag.punctureRepair => const {PlaceCategory.garage, PlaceCategory.fuel},
        PlaceTag.paddockStand => const {PlaceCategory.garage},
        PlaceTag.genuineParts => const {PlaceCategory.parts, PlaceCategory.garage},
        PlaceTag.bikeParking => const {PlaceCategory.recreation, PlaceCategory.fuel},
        PlaceTag.restrooms => const {PlaceCategory.fuel, PlaceCategory.recreation},
      };

  String get icon => switch (this) {
        PlaceTag.open24h => '🕒',
        PlaceTag.octane95 => '⛽',
        PlaceTag.digitalPayment => '💳',
        PlaceTag.efiDiagnostics => '🔌',
        PlaceTag.punctureRepair => '🛞',
        PlaceTag.paddockStand => '🏍️',
        PlaceTag.genuineParts => '✅',
        PlaceTag.bikeParking => '🅿️',
        PlaceTag.restrooms => '🚻',
      };

  /// Tags offered for [category], in declaration order.
  static List<PlaceTag> forCategory(PlaceCategory category) =>
      [for (final t in values) if (t.categories.contains(category)) t];

  /// Reads a stored `tags` list, keeping known names once each and dropping
  /// anything else (a newer build's tag, a typo from a seed script).
  static Set<PlaceTag> parseAll(Iterable<Object?>? raw) {
    if (raw == null) return const {};
    final byName = {for (final t in values) t.name: t};
    return {
      for (final value in raw)
        if (value is String && byName.containsKey(value)) byName[value]!,
    };
  }

  /// Upper bound on tags per place, mirrored by the `places` create rule in
  /// firestore.rules so a client can't attach an unbounded list.
  static const int maxPerPlace = 12;
}
