/// Internal beta features gated by hard-coded @handles.
///
/// Deliberately not a remote flag or a Firestore role: these are a handful of
/// internal riders trying out data-collection tools that aren't ready for
/// anyone else, and a code change to add someone is the right amount of
/// friction. Handles are stored lowercase without the `@`, matching
/// `ProfileRepository.setUsername`'s normalization.
class BetaTesters {
  BetaTesters._();

  /// Riders who see the "In a jam" / "Jam released" labelling buttons on the
  /// active ride screen (see jam_label_provider.dart).
  static const Set<String> jamLabelling = {'abraaraidev'};

  /// Riders who see the demo "Order" (cash-on-delivery) button on due parts
  /// in Maintenance. It places no real order — there is no parts partner
  /// yet — so everyone else doesn't see it at all.
  static const Set<String> partOrdering = {'abraaraidev'};

  static bool canLabelJams(String? username) =>
      jamLabelling.contains(_handle(username));

  static bool canOrderParts(String? username) =>
      partOrdering.contains(_handle(username));

  static String _handle(String? username) =>
      (username ?? '').trim().toLowerCase().replaceFirst('@', '');
}
