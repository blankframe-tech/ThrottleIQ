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
  custom,
}

enum ReminderStatus { ok, dueSoon, overdue }

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
      case ServiceType.custom: return 'Custom';
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
