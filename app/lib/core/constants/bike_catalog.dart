/// Curated Bangladesh-market brand → model list, powering the brand/model
/// suggestions on the Add/Edit Bike and onboarding "first bike" screens.
///
/// Suggestions only, never a restriction: both fields stay plain free-text
/// (via `Autocomplete`'s own text field), so a rider can always type a
/// brand or model that isn't listed here — that's the "or added custom"
/// half of the picker. This just makes the common case (one of the popular
/// brands/models actually sold here) a couple of taps instead of typing it
/// out.
///
/// Yamaha's FZ-S/FZS line is listed as a single canonical `FZS` model, not
/// `FZS-Fi V3`/`FZ-S V2`/etc. — matching `normalizeModelFamily` in
/// `slugify.dart`, which already merges every generation into one forum.
/// Suggesting the canonical name up front means fewer riders type a
/// version-specific name that has to be normalized later.
const Map<String, List<String>> bikeCatalog = {
  'Yamaha': ['FZS', 'MT-15', 'R15', 'YZF-R3', 'Saluto 125', 'Fazer', 'Ray ZR'],
  'Honda': ['CB Shine 125', 'CB150R Streetfire', 'X-Blade 160', 'CBR250RR', 'Livo'],
  'Bajaj': ['Pulsar 150', 'Pulsar NS160', 'Discover 125', 'CT 100', 'Platina'],
  'TVS': ['Apache RTR 160 4V', 'Apache RTR 165RP', 'Metro Plus 100', 'Raider 125'],
  'Suzuki': ['Gixxer 155', 'Gixxer SF 155', 'GSX-R150', 'Hayate EP'],
  'Hero': ['Splendor Plus', 'Hunk 150R', 'Glamour'],
  'Royal Enfield': ['Classic 350', 'Bullet 350', 'Meteor 350', 'Hunter 350', 'Himalayan 411'],
  'CF Moto': ['SR 250', 'SR 300', 'CF Light 230 Dual'],
  'KTM': ['Duke 200', 'Duke 250', 'RC 390'],
  'Kawasaki': ['Ninja 300', 'Z400'],
  'Runner': ['Turbo 100', 'Bullet 150'],
  'Lifan': ['KP100', 'KPR 150'],
  'Walton': ['Fizor 125', 'Raptor 150'],
};

List<String> get bikeCatalogBrands => bikeCatalog.keys.toList(growable: false);

/// Models for [brand], case/whitespace-insensitive. Empty (not an error) for
/// a brand that isn't in the catalog — the model field still works, it just
/// has no suggestions to offer, exactly as if the rider typed a custom brand.
List<String> modelsForBrand(String brand) {
  final key = brand.trim().toLowerCase();
  for (final entry in bikeCatalog.entries) {
    if (entry.key.toLowerCase() == key) return entry.value;
  }
  return const [];
}
