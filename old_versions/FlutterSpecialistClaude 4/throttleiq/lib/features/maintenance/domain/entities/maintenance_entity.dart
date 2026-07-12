import 'package:equatable/equatable.dart';

enum ServiceType { oilChange, airFilter, chain, tire, custom }

enum ReminderStatus { ok, dueSoon, overdue }

extension ServiceTypeExt on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.oilChange: return 'Oil Change';
      case ServiceType.airFilter: return 'Air Filter';
      case ServiceType.chain: return 'Chain Lube';
      case ServiceType.tire: return 'Tire Check';
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
  final DateTime createdAt;

  const MaintenanceEntity({
    required this.id,
    required this.bikeId,
    required this.serviceType,
    required this.date,
    required this.odometerKm,
    this.cost,
    this.notes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, bikeId, serviceType, date];
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
