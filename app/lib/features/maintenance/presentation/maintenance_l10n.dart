import '../../../l10n/app_localizations.dart';
import '../domain/calculators/maintenance_forecast.dart';
import '../domain/calculators/riding_conditions.dart';
import '../domain/catalog/schedule_templates.dart';
import '../domain/entities/maintenance_entity.dart';
import '../domain/entities/maintenance_profile.dart';
import 'service_type_l10n.dart';

/// Rider-facing names for the redesign's enums, in the app language.

String forecastLabel(CheckForecast f, AppLocalizations l10n) =>
    (f.customLabel != null && f.customLabel!.trim().isNotEmpty)
        ? f.customLabel!.trim()
        : f.serviceType.localizedLabel(l10n);

String configLabel(MaintenanceConfigEntity c, AppLocalizations l10n) =>
    (c.customLabel != null && c.customLabel!.trim().isNotEmpty)
        ? c.customLabel!.trim()
        : c.serviceType.localizedLabel(l10n);

String paperworkLabel(PaperworkKind k, AppLocalizations l10n) => switch (k) {
      PaperworkKind.taxToken => l10n.paperworkTaxToken,
      PaperworkKind.insurance => l10n.paperworkInsurance,
      PaperworkKind.fitness => l10n.paperworkFitness,
      PaperworkKind.registration => l10n.paperworkRegistration,
      PaperworkKind.drivingLicence => l10n.paperworkDrivingLicence,
    };

String shopKindLabel(ShopKind k, AppLocalizations l10n) => switch (k) {
      ShopKind.authorized => l10n.shopKindAuthorized,
      ShopKind.local => l10n.shopKindLocal,
      ShopKind.self => l10n.shopKindSelf,
    };

String oilGradeLabel(OilGrade g, AppLocalizations l10n) => switch (g) {
      OilGrade.mineral => l10n.oilGradeMineral,
      OilGrade.semiSynthetic => l10n.oilGradeSemi,
      OilGrade.fullSynthetic => l10n.oilGradeFull,
    };

String ridingProfileLabel(RidingProfile p, AppLocalizations l10n) =>
    switch (p) {
      RidingProfile.normal => l10n.ridingProfileNormal,
      RidingProfile.severe => l10n.ridingProfileSevere,
    };

String bundleLabel(ServiceBundle b, AppLocalizations l10n) => switch (b) {
      ServiceBundle.oilChange => l10n.bundleOilChange,
      ServiceBundle.generalService => l10n.bundleGeneralService,
      ServiceBundle.chainCare => l10n.bundleChainCare,
      ServiceBundle.brakeService => l10n.bundleBrakeService,
    };

String precheckLabel(PrecheckItem i, AppLocalizations l10n) => switch (i) {
      PrecheckItem.tires => l10n.precheckTires,
      PrecheckItem.controls => l10n.precheckControls,
      PrecheckItem.lights => l10n.precheckLights,
      PrecheckItem.oil => l10n.precheckOil,
      PrecheckItem.chain => l10n.precheckChain,
      PrecheckItem.stands => l10n.precheckStands,
    };

String precheckHint(PrecheckItem i, AppLocalizations l10n) => switch (i) {
      PrecheckItem.tires => l10n.precheckTiresHint,
      PrecheckItem.controls => l10n.precheckControlsHint,
      PrecheckItem.lights => l10n.precheckLightsHint,
      PrecheckItem.oil => l10n.precheckOilHint,
      PrecheckItem.chain => l10n.precheckChainHint,
      PrecheckItem.stands => l10n.precheckStandsHint,
    };

/// "Stop-and-go 38% · −20%" style chip text.
String adaptReasonLabel(AdaptReason r, AppLocalizations l10n) {
  final pct = r.percentShorter;
  return switch (r.kind) {
    AdaptReasonKind.stopAndGo =>
      l10n.adaptStopAndGo(((r.measure ?? 0) * 100).round(), pct),
    AdaptReasonKind.hardBraking =>
      l10n.adaptHardBraking((r.measure ?? 0).toStringAsFixed(1), pct),
    AdaptReasonKind.severeRoads => l10n.adaptSevereRoads(pct),
  };
}
