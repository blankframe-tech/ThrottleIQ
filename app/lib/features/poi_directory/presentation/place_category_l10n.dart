import '../../../l10n/app_localizations.dart';
import '../domain/entities/place_entity.dart';

/// [PlaceCategory.displayName] in the rider's language. The domain getter stays
/// English because it is also stored as the default name of an imported place
/// (see `overpass_service.dart`); what is *displayed* goes through here.
extension PlaceCategoryL10n on PlaceCategory {
  String localizedName(AppLocalizations l10n) => switch (this) {
        PlaceCategory.fuel => l10n.placeCatFuel,
        PlaceCategory.garage => l10n.placeCatGarage,
        PlaceCategory.parts => l10n.placeCatParts,
        PlaceCategory.aiCamera => l10n.placeCatAiCamera,
        PlaceCategory.police => l10n.placeCatPolice,
        PlaceCategory.recreation => l10n.placeCatRecreation,
      };
}
