import '../../../l10n/app_localizations.dart';
import '../domain/place_tags.dart';

/// [PlaceTag] in the rider's language.
extension PlaceTagL10n on PlaceTag {
  String localizedName(AppLocalizations l10n) => switch (this) {
        PlaceTag.open24h => l10n.placeTagOpen24h,
        PlaceTag.octane95 => l10n.placeTagOctane95,
        PlaceTag.digitalPayment => l10n.placeTagDigitalPayment,
        PlaceTag.efiDiagnostics => l10n.placeTagEfiDiagnostics,
        PlaceTag.punctureRepair => l10n.placeTagPunctureRepair,
        PlaceTag.paddockStand => l10n.placeTagPaddockStand,
        PlaceTag.genuineParts => l10n.placeTagGenuineParts,
        PlaceTag.bikeParking => l10n.placeTagBikeParking,
        PlaceTag.restrooms => l10n.placeTagRestrooms,
      };
}
