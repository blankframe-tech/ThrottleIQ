import '../../../l10n/app_localizations.dart';
import '../domain/entities/maintenance_entity.dart';

/// Localized names for the maintenance catalogue.
///
/// The domain enums keep their English `label`/`description` (they are
/// persisted by `name`, and diagnostics read them); what a rider *sees* goes
/// through here so it follows the app language.
extension MaintenanceCategoryL10n on MaintenanceCategory {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        MaintenanceCategory.engine => l10n.maintCatEngine,
        MaintenanceCategory.drivetrain => l10n.maintCatDrivetrain,
        MaintenanceCategory.braking => l10n.maintCatBraking,
        MaintenanceCategory.chassisElectrical => l10n.maintCatChassisElectrical,
      };
}

extension ServiceTypeL10n on ServiceType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        ServiceType.oilChange => l10n.svcTypeOilChange,
        ServiceType.airFilter => l10n.svcTypeAirFilter,
        ServiceType.chain => l10n.svcTypeChain,
        ServiceType.tire => l10n.svcTypeTire,
        ServiceType.radiatorCoolant => l10n.svcTypeRadiatorCoolant,
        ServiceType.frontDiscPads => l10n.svcTypeFrontDiscPads,
        ServiceType.rearDrumPads => l10n.svcTypeRearDrumPads,
        ServiceType.brakeFluid => l10n.svcTypeBrakeFluid,
        ServiceType.sparkPlug => l10n.svcTypeSparkPlug,
        ServiceType.battery => l10n.svcTypeBattery,
        ServiceType.valveClearance => l10n.svcTypeValveClearance,
        ServiceType.clutchCable => l10n.svcTypeClutchCable,
        ServiceType.suspension => l10n.svcTypeSuspension,
        ServiceType.oilFilter => l10n.svcTypeOilFilter,
        ServiceType.chainTension => l10n.svcTypeChainTension,
        ServiceType.brakeRotors => l10n.svcTypeBrakeRotors,
        ServiceType.forkSeals => l10n.svcTypeForkSeals,
        ServiceType.wheelBearings => l10n.svcTypeWheelBearings,
        ServiceType.driveBelt => l10n.svcTypeDriveBelt,
        ServiceType.throttleCables => l10n.svcTypeThrottleCables,
        ServiceType.fuel => l10n.svcTypeFuel,
        ServiceType.custom => l10n.svcTypeCustom,
      };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
        ServiceType.oilChange => l10n.svcDescOilChange,
        ServiceType.oilFilter => l10n.svcDescOilFilter,
        ServiceType.airFilter => l10n.svcDescAirFilter,
        ServiceType.chain => l10n.svcDescChain,
        ServiceType.chainTension => l10n.svcDescChainTension,
        ServiceType.tire => l10n.svcDescTire,
        ServiceType.radiatorCoolant => l10n.svcDescRadiatorCoolant,
        ServiceType.frontDiscPads => l10n.svcDescFrontDiscPads,
        ServiceType.rearDrumPads => l10n.svcDescRearDrumPads,
        ServiceType.brakeFluid => l10n.svcDescBrakeFluid,
        ServiceType.sparkPlug => l10n.svcDescSparkPlug,
        ServiceType.battery => l10n.svcDescBattery,
        ServiceType.valveClearance => l10n.svcDescValveClearance,
        ServiceType.clutchCable => l10n.svcDescClutchCable,
        ServiceType.throttleCables => l10n.svcDescThrottleCables,
        ServiceType.suspension => l10n.svcDescSuspension,
        ServiceType.forkSeals => l10n.svcDescForkSeals,
        ServiceType.brakeRotors => l10n.svcDescBrakeRotors,
        ServiceType.wheelBearings => l10n.svcDescWheelBearings,
        ServiceType.driveBelt => l10n.svcDescDriveBelt,
        ServiceType.fuel => l10n.svcDescFuel,
        ServiceType.custom => l10n.svcDescCustom,
      };
}

extension MaintenanceEntityL10n on MaintenanceEntity {
  /// [MaintenanceEntity.displayLabel] in the rider's language: their own name
  /// for a custom check, otherwise the catalogue name.
  String localizedDisplayLabel(AppLocalizations l10n) =>
      serviceType == ServiceType.custom &&
              customLabel != null &&
              customLabel!.trim().isNotEmpty
          ? customLabel!.trim()
          : serviceType.localizedLabel(l10n);
}
