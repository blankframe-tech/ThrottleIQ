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
  fuel,
  custom,
}

/// Where a tracked check stands. [unknown] means there is nothing to count
/// from — the item was never logged and has no baseline — which is shown as
/// "set last done" rather than guessed as overdue (a bike added at 25,000 km
/// used to light up every check red on day one).
enum ReminderStatus { ok, dueSoon, overdue, unknown }

/// Who did the work on a service visit.
enum ShopKind { authorized, local, self }

extension ShopKindExt on ShopKind {
  static ShopKind? fromString(String? s) =>
      ShopKind.values.where((k) => k.name == s).firstOrNull;
}

/// Whether a check's interval came from a schedule template / oil grade, or
/// was set by the rider. Only template intervals are retuned when the rider
/// picks a new template or oil grade — their own edits are never overwritten.
enum IntervalSource { template, user }

/// Prefix of a custom tracked check's key (`custom:<uuid>`). Built-in checks
/// are keyed by their [ServiceType] name.
const String kCustomCheckPrefix = 'custom:';

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
      case ServiceType.fuel: return 'Fuel';
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
      case ServiceType.fuel:
        return 'Track fuel refills, tank range, and fuel type.';
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
      case ServiceType.fuel:
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
      case ServiceType.fuel: return 300;
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

  /// Time limit paired with [defaultIntervalKm], whichever comes first.
  /// Null where wear is purely distance-driven (pads, valves, bearings).
  /// Brake fluid, coolant and batteries age on the stand, so they come due
  /// even on a bike that is never ridden.
  int? get defaultIntervalDays {
    switch (this) {
      case ServiceType.oilChange: return 180;
      case ServiceType.oilFilter: return 365;
      case ServiceType.chain: return 30;
      case ServiceType.chainTension: return 60;
      case ServiceType.tire: return 30;
      case ServiceType.clutchCable: return 180;
      case ServiceType.throttleCables: return 365;
      case ServiceType.battery: return 365;
      case ServiceType.airFilter: return 365;
      case ServiceType.sparkPlug: return 730;
      case ServiceType.forkSeals: return 730;
      case ServiceType.radiatorCoolant: return 730;
      case ServiceType.brakeFluid: return 730;
      case ServiceType.fuel:
      case ServiceType.frontDiscPads:
      case ServiceType.rearDrumPads:
      case ServiceType.suspension:
      case ServiceType.wheelBearings:
      case ServiceType.driveBelt:
      case ServiceType.valveClearance:
      case ServiceType.brakeRotors:
      case ServiceType.custom:
        return null;
    }
  }

  /// Items too frequent or too low-stakes to headline the page, notify about,
  /// or put on the home-screen widget. Fuel resets every few hundred km and
  /// the bike's own gauge already says when it's low.
  bool get isLowStakes => this == ServiceType.fuel;

  /// Sensible default recommendation for most motorcycles.
  bool get isRecommendedDefault {
    switch (this) {
      case ServiceType.fuel:
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

  /// What this item cost on its own, when known. A multi-item visit usually
  /// has only a total — see [visitTotal].
  final double? cost;
  final String? notes;

  /// The rider's own name for the service, set only when [serviceType] is
  /// [ServiceType.custom] ("Radiator flush", "Steering head bearings"...).
  /// Read through [displayLabel] rather than directly.
  final String? customLabel;
  final DateTime createdAt;

  /// The visit this item was done in. Every item ticked in one "Log a visit"
  /// shares it; null on logs written before visits existed, which are each a
  /// visit of their own (see [visitKey]).
  final String? visitId;

  /// The tracked check this log resets, when it isn't simply
  /// [serviceType]'s name — a custom tracked check (`custom:<id>`).
  final String? checkKey;

  /// Visit-level details, repeated on each item of the visit.
  final String? shopName;
  final ShopKind? shopKind;
  final String? receiptPath;

  /// The whole visit's bill, when the rider entered one total rather than a
  /// price per item.
  final double? visitTotal;

  /// "free:1", "free:2"… for a warranty free service.
  final String? visitLabel;

  /// Part used for this item (oil brand, tyre make…) and its grade/spec.
  final String? partBrand;
  final String? partGrade;

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
    this.visitId,
    this.checkKey,
    this.shopName,
    this.shopKind,
    this.receiptPath,
    this.visitTotal,
    this.visitLabel,
    this.partBrand,
    this.partGrade,
  });

  /// The tracked check this log counts toward.
  String get key => checkKey ?? serviceType.name;

  /// Groups logs into visits; a pre-visit log is a visit of one.
  String get visitKey => visitId ?? id;

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
  List<Object?> get props => [
        id,
        bikeId,
        serviceType,
        date,
        customLabel,
        odometerKm,
        cost,
        visitId,
        checkKey,
        visitTotal,
      ];
}

class MaintenanceConfigEntity extends Equatable {
  final String bikeId;
  final ServiceType serviceType;

  /// Distance between services. 0 means "time only" (e.g. a battery check
  /// tracked purely by date).
  final double intervalKm;

  /// Time between services, whichever of the two comes first. Null = km only.
  final int? intervalDays;
  final bool isEnabled;
  final String? notes;

  /// What the rider typically pays for one service of this item, in the
  /// app's currency (৳). Feeds the per-ride running-cost estimate — see
  /// `RideCostCalculator` — as the fallback when no logged service of this
  /// type carries an actual cost yet. Null when never set.
  final double? typicalCost;

  /// Advance warning: "due soon" this far before the limit. Null = the
  /// default (see `maintenance_forecast.dart`).
  final double? warnKm;
  final int? warnDays;

  /// When the item was last done if that predates the app's logs — set in
  /// setup ("last oil change was at 12,000 km in May") or from "Set last
  /// done". Ignored once a real log exists.
  final double? baselineKm;
  final DateTime? baselineDate;

  final IntervalSource source;

  /// A custom tracked check's id (its key is `custom:<id>`) and name.
  final String? customId;
  final String? customLabel;

  const MaintenanceConfigEntity({
    required this.bikeId,
    required this.serviceType,
    required this.intervalKm,
    this.intervalDays,
    this.isEnabled = true,
    this.notes,
    this.typicalCost,
    this.warnKm,
    this.warnDays,
    this.baselineKm,
    this.baselineDate,
    this.source = IntervalSource.template,
    this.customId,
    this.customLabel,
  });

  /// The check's identity within a bike: the [ServiceType] name, or
  /// `custom:<id>` for a rider-defined tracked check.
  String get key =>
      customId != null ? '$kCustomCheckPrefix$customId' : serviceType.name;

  bool get isCustom => customId != null;

  bool get hasBaseline => baselineKm != null || baselineDate != null;

  MaintenanceConfigEntity copyWith({
    String? bikeId,
    ServiceType? serviceType,
    double? intervalKm,
    int? intervalDays,
    bool clearIntervalDays = false,
    bool? isEnabled,
    String? notes,
    double? typicalCost,
    bool clearTypicalCost = false,
    double? warnKm,
    bool clearWarnKm = false,
    int? warnDays,
    bool clearWarnDays = false,
    double? baselineKm,
    DateTime? baselineDate,
    bool clearBaseline = false,
    IntervalSource? source,
    String? customLabel,
  }) {
    return MaintenanceConfigEntity(
      bikeId: bikeId ?? this.bikeId,
      serviceType: serviceType ?? this.serviceType,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalDays:
          clearIntervalDays ? null : (intervalDays ?? this.intervalDays),
      isEnabled: isEnabled ?? this.isEnabled,
      notes: notes ?? this.notes,
      typicalCost:
          clearTypicalCost ? null : (typicalCost ?? this.typicalCost),
      warnKm: clearWarnKm ? null : (warnKm ?? this.warnKm),
      warnDays: clearWarnDays ? null : (warnDays ?? this.warnDays),
      baselineKm: clearBaseline ? null : (baselineKm ?? this.baselineKm),
      baselineDate:
          clearBaseline ? null : (baselineDate ?? this.baselineDate),
      source: source ?? this.source,
      customId: customId,
      customLabel: customLabel ?? this.customLabel,
    );
  }

  @override
  List<Object?> get props => [
        bikeId,
        serviceType,
        intervalKm,
        intervalDays,
        isEnabled,
        notes,
        typicalCost,
        warnKm,
        warnDays,
        baselineKm,
        baselineDate,
        source,
        customId,
        customLabel,
      ];
}

/// Per-bike fuel economics used to price a ride's fuel. Stored canonically
/// in metric (price per litre, km per litre) whatever unit the rider typed
/// them in — conversion happens at the edges (see `fuel_units.dart`).
class BikeRunningCostEntity extends Equatable {
  final String bikeId;

  /// Price of one litre of fuel, in ৳.
  final double? fuelPricePerLitre;

  /// The bike's average mileage, km per litre.
  final double? kmPerLitre;

  const BikeRunningCostEntity({
    required this.bikeId,
    this.fuelPricePerLitre,
    this.kmPerLitre,
  });

  bool get hasFuelData =>
      (fuelPricePerLitre ?? 0) > 0 && (kmPerLitre ?? 0) > 0;

  @override
  List<Object?> get props => [bikeId, fuelPricePerLitre, kmPerLitre];
}

