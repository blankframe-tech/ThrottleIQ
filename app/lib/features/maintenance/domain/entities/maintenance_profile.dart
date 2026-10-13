import 'package:equatable/equatable.dart';

import '../calculators/riding_conditions.dart';
import '../catalog/schedule_templates.dart';

/// Per-bike maintenance setup: which schedule it follows, how it's ridden,
/// the oil it runs on, and whether intervals adapt to telemetry.
///
/// One row per bike in `bike_maintenance_profiles`; backed up with the rest
/// of the bike's maintenance settings (`MaintenanceSettingsSync`). A bike
/// with no row hasn't been through setup — the page shows the setup card.
class MaintenanceProfileEntity extends Equatable {
  final String bikeId;
  final String templateId;
  final RidingProfile ridingProfile;
  final OilGrade? oilGrade;

  /// "Adapt intervals to my riding" — Y-Connect's Auto vs User mode.
  final bool adaptIntervals;
  final DateTime? onboardedAt;

  /// Last T-CLOCS quick check, for the weekly nudge.
  final DateTime? lastPrecheckAt;

  const MaintenanceProfileEntity({
    required this.bikeId,
    required this.templateId,
    this.ridingProfile = RidingProfile.normal,
    this.oilGrade,
    this.adaptIntervals = true,
    this.onboardedAt,
    this.lastPrecheckAt,
  });

  ScheduleTemplate get template => templateById(templateId);

  MaintenanceProfileEntity copyWith({
    String? templateId,
    RidingProfile? ridingProfile,
    OilGrade? oilGrade,
    bool? adaptIntervals,
    DateTime? onboardedAt,
    DateTime? lastPrecheckAt,
  }) =>
      MaintenanceProfileEntity(
        bikeId: bikeId,
        templateId: templateId ?? this.templateId,
        ridingProfile: ridingProfile ?? this.ridingProfile,
        oilGrade: oilGrade ?? this.oilGrade,
        adaptIntervals: adaptIntervals ?? this.adaptIntervals,
        onboardedAt: onboardedAt ?? this.onboardedAt,
        lastPrecheckAt: lastPrecheckAt ?? this.lastPrecheckAt,
      );

  Map<String, dynamic> toMap() => {
        'bike_id': bikeId,
        'template_id': templateId,
        'riding_profile': ridingProfile.name,
        'oil_grade': oilGrade?.name,
        'adapt_intervals': adaptIntervals ? 1 : 0,
        'onboarded_at': onboardedAt?.toIso8601String(),
        'last_precheck_at': lastPrecheckAt?.toIso8601String(),
      };

  static MaintenanceProfileEntity fromMap(Map<String, dynamic> m) =>
      MaintenanceProfileEntity(
        bikeId: m['bike_id'] as String,
        templateId: (m['template_id'] as String?) ?? kDefaultTemplateId,
        ridingProfile:
            RidingProfileExt.fromString(m['riding_profile'] as String?),
        oilGrade: OilGradeExt.fromString(m['oil_grade'] as String?),
        adaptIntervals: (m['adapt_intervals'] as int? ?? 1) == 1,
        onboardedAt: DateTime.tryParse(m['onboarded_at'] as String? ?? ''),
        lastPrecheckAt:
            DateTime.tryParse(m['last_precheck_at'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [
        bikeId,
        templateId,
        ridingProfile,
        oilGrade,
        adaptIntervals,
        onboardedAt,
        lastPrecheckAt,
      ];
}

/// Bike papers a BD rider can be stopped for, each with an expiry.
enum PaperworkKind { taxToken, insurance, fitness, registration, drivingLicence }

extension PaperworkKindExt on PaperworkKind {
  static PaperworkKind? fromString(String? s) =>
      PaperworkKind.values.where((k) => k.name == s).firstOrNull;
}

class PaperworkEntity extends Equatable {
  final String bikeId;
  final PaperworkKind kind;
  final DateTime expiresOn;
  final String? notes;

  const PaperworkEntity({
    required this.bikeId,
    required this.kind,
    required this.expiresOn,
    this.notes,
  });

  /// Reminders start this long before expiry.
  static const warnDays = 30;

  int daysLeft(DateTime now) {
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(expiresOn.year, expiresOn.month, expiresOn.day);
    return (b.difference(a).inHours / 24).round();
  }

  Map<String, dynamic> toMap() => {
        'bike_id': bikeId,
        'kind': kind.name,
        'expires_on': expiresOn.toIso8601String(),
        'notes': (notes != null && notes!.trim().isNotEmpty) ? notes : null,
      };

  static PaperworkEntity? fromMap(Map<String, dynamic> m) {
    final kind = PaperworkKindExt.fromString(m['kind'] as String?);
    final date = DateTime.tryParse(m['expires_on'] as String? ?? '');
    if (kind == null || date == null) return null;
    return PaperworkEntity(
      bikeId: m['bike_id'] as String,
      kind: kind,
      expiresOn: date,
      notes: m['notes'] as String?,
    );
  }

  @override
  List<Object?> get props => [bikeId, kind, expiresOn, notes];
}

/// The MSF T-CLOCS pre-ride inspection, as six quick tiles.
enum PrecheckItem { tires, controls, lights, oil, chain, stands }

extension PrecheckItemExt on PrecheckItem {
  static PrecheckItem? fromString(String? s) =>
      PrecheckItem.values.where((k) => k.name == s).firstOrNull;
}

/// A failed quick-check tile, open until the rider marks it fixed. Shown in
/// "Needs attention" next to due checks (AUTOsist's "failed inspection item
/// becomes a work order").
class PrecheckIssue extends Equatable {
  final String id;
  final String bikeId;
  final PrecheckItem item;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const PrecheckIssue({
    required this.id,
    required this.bikeId,
    required this.item,
    required this.createdAt,
    this.resolvedAt,
  });

  static PrecheckIssue? fromMap(Map<String, dynamic> m) {
    final item = PrecheckItemExt.fromString(m['item'] as String?);
    if (item == null) return null;
    return PrecheckIssue(
      id: m['id'] as String,
      bikeId: m['bike_id'] as String,
      item: item,
      createdAt: DateTime.parse(m['created_at'] as String),
      resolvedAt: DateTime.tryParse(m['resolved_at'] as String? ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, bikeId, item, createdAt, resolvedAt];
}
