import 'package:equatable/equatable.dart';

/// Persisted by `name`, so existing values must never be renamed — a rename
/// would orphan every already-logged row. New types are appended, with
/// [ServiceType.custom] deliberately kept last so it reads as the escape
/// hatch at the end of the picker.
enum ServiceType {
  oilChange,
  airFilter,
  chain,
  tire,
  radiatorCoolant,
  frontDiscPads,
  rearDrumPads,
  brakeFluid,
  sparkPlug,
  battery,
  valveClearance,
  clutchCable,
  suspension,
  oilFilter,
  chainTension,
  brakeRotors,
  forkSeals,
  wheelBearings,
  driveBelt,
  throttleCables,
  custom,
}

enum ReminderStatus { ok, dueSoon, overdue }

enum MaintenanceCategory {
  engine,
  drivetrain,
  braking,
  chassisElectrical,
}

extension MaintenanceCategoryExt on MaintenanceCategory {
  String get label {
    switch (this) {
      case MaintenanceCategory.engine:
        return 'Engine & Fluids';
      case MaintenanceCategory.drivetrain:
        return 'Drive & Controls';
      case MaintenanceCategory.braking:
        return 'Braking System';
      case MaintenanceCategory.chassisElectrical:
        return 'Chassis & Electrical';
    }
  }
}

extension ServiceTypeExt on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.oilChange: return 'Oil Change';
      case ServiceType.airFilter: return 'Air Filter';
      case ServiceType.chain: return 'Chain Lube';
      case ServiceType.tire: return 'Tire Check';
      case ServiceType.radiatorCoolant: return 'Radiator / Coolant';
      case ServiceType.frontDiscPads: return 'Front Disc Pads';
      case ServiceType.rearDrumPads: return 'Rear Drum Pads';
      case ServiceType.brakeFluid: return 'Brake Fluid';
      case ServiceType.sparkPlug: return 'Spark Plug';
      case ServiceType.battery: return 'Battery';
      case ServiceType.valveClearance: return 'Valve Clearance';
      case ServiceType.clutchCable: return 'Clutch Cable';
      case ServiceType.suspension: return 'Suspension';
      case ServiceType.oilFilter: return 'Oil Filter';
      case ServiceType.chainTension: return 'Chain Slack & Tension';
      case ServiceType.brakeRotors: return 'Brake Rotors / Discs';
      case ServiceType.forkSeals: return 'Fork Oil & Seals';
      case ServiceType.wheelBearings: return 'Wheel Bearings';
      case ServiceType.driveBelt: return 'Drive Belt';
      case ServiceType.throttleCables: return 'Throttle & Cables';
      case ServiceType.custom: return 'Custom';
    }
  }

  String get description {
    switch (this) {
      case ServiceType.oilChange:
        return 'Drain engine oil & replace with fresh lubricant.';
      case ServiceType.oilFilter:
        return 'Replace oil filter element to prevent contaminant buildup.';
      case ServiceType.airFilter:
        return 'Clean or replace intake filter for optimal airflow.';
      case ServiceType.chain:
        return 'Clean road grime & apply chain lube to drive chain.';
      case ServiceType.chainTension:
        return 'Check drive chain slack & align rear axle.';
      case ServiceType.tire:
        return 'Inspect tire pressures, tread wear & dry rot.';
      case ServiceType.radiatorCoolant:
        return 'Flush and refill radiator coolant fluid.';
      case ServiceType.frontDiscPads:
        return 'Check front brake pad friction material thickness.';
      case ServiceType.rearDrumPads:
        return 'Inspect rear brake pads or drum brake shoes.';
      case ServiceType.brakeFluid:
        return 'Bleed & replenish hydraulic DOT brake fluid.';
      case ServiceType.sparkPlug:
        return 'Inspect electrode gap or replace spark plugs.';
      case ServiceType.battery:
        return 'Test terminal voltage, connections & charge state.';
      case ServiceType.valveClearance:
        return 'Measure & adjust intake / exhaust valve clearances.';
      case ServiceType.clutchCable:
        return 'Check lever free-play & lube clutch cable.';
      case ServiceType.throttleCables:
        return 'Inspect throttle play, snap-back & lube cables.';
      case ServiceType.suspension:
        return 'Inspect rear shock damping & linkage pivot bushings.';
      case ServiceType.forkSeals:
        return 'Inspect front fork seals for oil weeping & change fork oil.';
      case ServiceType.brakeRotors:
        return 'Measure brake disc thickness & check for warping.';
      case ServiceType.wheelBearings:
        return 'Inspect front & rear wheel bearings for play/roughness.';
      case ServiceType.driveBelt:
        return 'Check belt deflection, teeth condition & tension.';
      case ServiceType.custom:
        return 'Rider-defined maintenance check.';
    }
  }

  MaintenanceCategory get category {
    switch (this) {
      case ServiceType.oilChange:
      case ServiceType.oilFilter:
      case ServiceType.airFilter:
      case ServiceType.radiatorCoolant:
      case ServiceType.sparkPlug:
      case ServiceType.valveClearance:
        return MaintenanceCategory.engine;
      case ServiceType.chain:
      case ServiceType.chainTension:
      case ServiceType.clutchCable:
      case ServiceType.throttleCables:
      case ServiceType.driveBelt:
        return MaintenanceCategory.drivetrain;
      case ServiceType.frontDiscPads:
      case ServiceType.rearDrumPads:
      case ServiceType.brakeFluid:
      case ServiceType.brakeRotors:
        return MaintenanceCategory.braking;
      case ServiceType.tire:
      case ServiceType.battery:
      case ServiceType.suspension:
      case ServiceType.forkSeals:
      case ServiceType.wheelBearings:
      case ServiceType.custom:
        return MaintenanceCategory.chassisElectrical;
    }
  }

  double get defaultIntervalKm {
    switch (this) {
      case ServiceType.oilChange: return 1500;
      case ServiceType.oilFilter: return 3000;
      case ServiceType.chain: return 600;
      case ServiceType.chainTension: return 1000;
      case ServiceType.tire: return 3000;
      case ServiceType.clutchCable: return 3000;
      case ServiceType.throttleCables: return 5000;
      case ServiceType.battery: return 6000;
      case ServiceType.airFilter: return 8000;
      case ServiceType.sparkPlug: return 10000;
      case ServiceType.frontDiscPads: return 12000;
      case ServiceType.rearDrumPads: return 12000;
      case ServiceType.forkSeals: return 15000;
      case ServiceType.radiatorCoolant: return 15000;
      case ServiceType.brakeFluid: return 18000;
      case ServiceType.suspension: return 18000;
      case ServiceType.wheelBearings: return 20000;
      case ServiceType.driveBelt: return 20000;
      case ServiceType.valveClearance: return 20000;
      case ServiceType.brakeRotors: return 25000;
      case ServiceType.custom: return 5000;
    }
  }

  /// Sensible default recommendation for most motorcycles.
  bool get isRecommendedDefault {
    switch (this) {
      case ServiceType.oilChange:
      case ServiceType.oilFilter:
      case ServiceType.chain:
      case ServiceType.chainTension:
      case ServiceType.tire:
      case ServiceType.airFilter:
      case ServiceType.frontDiscPads:
      case ServiceType.brakeFluid:
        return true;
      default:
        return false;
    }
  }

  String get value => name;

  static ServiceType fromString(String s) {
    return ServiceType.values.firstWhere((e) => e.name == s, orElse: () => ServiceType.custom);
  }
}

class MaintenanceEntity extends Equatable {
  final String id;
  final String bikeId;
  final ServiceType serviceType;
  final DateTime date;
  final double odometerKm;
  final double? cost;
  final String? notes;

  /// The rider's own name for the service, set only when [serviceType] is
  /// [ServiceType.custom] ("Radiator flush", "Steering head bearings"...).
  /// Read through [displayLabel] rather than directly.
  final String? customLabel;
  final DateTime createdAt;

  const MaintenanceEntity({
    required this.id,
    required this.bikeId,
    required this.serviceType,
    required this.date,
    required this.odometerKm,
    this.cost,
    this.notes,
    this.customLabel,
    required this.createdAt,
  });

  /// What to show the rider for this log — the custom name when they gave
  /// one, the built-in label otherwise (including for older custom rows
  /// logged before custom names existed, which have no [customLabel]).
  String get displayLabel {
    if (serviceType == ServiceType.custom &&
        customLabel != null &&
        customLabel!.trim().isNotEmpty) {
      return customLabel!.trim();
    }
    return serviceType.label;
  }

  @override
  List<Object?> get props => [id, bikeId, serviceType, date, customLabel];
}

class MaintenanceReminder {
  final ServiceType serviceType;
  final ReminderStatus status;
  final double kmSinceService;
  final double kmLimit;
  final DateTime? lastServiceDate;

  const MaintenanceReminder({
    required this.serviceType,
    required this.status,
    required this.kmSinceService,
    required this.kmLimit,
    this.lastServiceDate,
  });
}

class MaintenanceConfigEntity extends Equatable {
  final String bikeId;
  final ServiceType serviceType;
  final double intervalKm;
  final bool isEnabled;

  const MaintenanceConfigEntity({
    required this.bikeId,
    required this.serviceType,
    required this.intervalKm,
    this.isEnabled = true,
  });

  MaintenanceConfigEntity copyWith({
    String? bikeId,
    ServiceType? serviceType,
    double? intervalKm,
    bool? isEnabled,
  }) {
    return MaintenanceConfigEntity(
      bikeId: bikeId ?? this.bikeId,
      serviceType: serviceType ?? this.serviceType,
      intervalKm: intervalKm ?? this.intervalKm,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [bikeId, serviceType, intervalKm, isEnabled];
}

