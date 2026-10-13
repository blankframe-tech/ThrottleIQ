import 'maintenance_entity.dart';

/// One trip to the mechanic: every item logged together. Not stored as its
/// own row — it is the logs sharing a [MaintenanceEntity.visitKey], so a log
/// from before visits existed is simply a visit of one.
class ServiceVisit {
  final String id;
  final List<MaintenanceEntity> items;

  const ServiceVisit(this.id, this.items);

  MaintenanceEntity get _lead => items.first;
  String get bikeId => _lead.bikeId;
  DateTime get date => _lead.date;
  double get odometerKm => _lead.odometerKm;
  String? get shopName => _lead.shopName;
  ShopKind? get shopKind => _lead.shopKind;
  String? get receiptPath => _lead.receiptPath;
  String? get visitLabel => _lead.visitLabel;

  /// Notes are per visit in the UI; older single logs carry their own.
  String? get notes => items
      .map((i) => i.notes)
      .where((n) => n != null && n.trim().isNotEmpty)
      .firstOrNull;

  /// The bill: the entered total when there is one, else the sum of item
  /// prices. Null when nothing was priced.
  double? get totalCost {
    final total = items.map((i) => i.visitTotal).whereType<double>().firstOrNull;
    if (total != null) return total;
    final priced = items.map((i) => i.cost).whereType<double>();
    return priced.isEmpty ? null : priced.fold<double>(0, (a, b) => a + b);
  }

  /// Warranty free-service number, from a `free:N` label.
  int? get freeServiceNumber {
    final l = visitLabel;
    if (l == null || !l.startsWith('free:')) return null;
    return int.tryParse(l.substring(5));
  }
}

/// Groups [logs] into visits, newest first.
List<ServiceVisit> groupVisits(List<MaintenanceEntity> logs) {
  final byKey = <String, List<MaintenanceEntity>>{};
  for (final l in logs) {
    (byKey[l.visitKey] ??= []).add(l);
  }
  final visits = [
    for (final e in byKey.entries)
      ServiceVisit(
          e.key,
          List.of(e.value)
            ..sort((a, b) => a.serviceType.index.compareTo(b.serviceType.index))),
  ];
  visits.sort((a, b) {
    final d = b.date.compareTo(a.date);
    if (d != 0) return d;
    return b.odometerKm.compareTo(a.odometerKm);
  });
  return visits;
}

/// Total spend across visits (each visit's bill counted once).
double totalSpend(List<MaintenanceEntity> logs) => groupVisits(logs)
    .map((v) => v.totalCost ?? 0)
    .fold<double>(0, (a, b) => a + b);

/// One ticked item in "Log a visit".
class VisitItemDraft {
  final ServiceType type;

  /// Set for a custom tracked check (`custom:<id>`); null for built-ins.
  final String? checkKey;
  final String? customLabel;
  final double? cost;
  final String? partBrand;
  final String? partGrade;

  const VisitItemDraft({
    required this.type,
    this.checkKey,
    this.customLabel,
    this.cost,
    this.partBrand,
    this.partGrade,
  });

  String get key => checkKey ?? type.name;
}

/// What the visit sheet hands the provider to save.
class VisitDraft {
  final DateTime date;
  final double odometerKm;
  final List<VisitItemDraft> items;

  /// The whole bill, when entered as one number.
  final double? totalCost;
  final String? shopName;
  final ShopKind? shopKind;
  final String? receiptPath;
  final String? notes;
  final String? visitLabel;

  const VisitDraft({
    required this.date,
    required this.odometerKm,
    required this.items,
    this.totalCost,
    this.shopName,
    this.shopKind,
    this.receiptPath,
    this.notes,
    this.visitLabel,
  });
}

/// The log rows for [draft], reusing [existing] rows' ids where the same
/// check is still ticked (an edit updates them in place). Pure, so the
/// cost-splitting rules are testable.
///
/// Cost rules: a one-item visit stores its price as the item's [cost]; a
/// multi-item visit stores per-item prices where given and the bill as
/// [MaintenanceEntity.visitTotal] on every row.
List<MaintenanceEntity> buildVisitLogs({
  required String bikeId,
  required String visitId,
  required VisitDraft draft,
  required String Function() newId,
  required DateTime now,
  List<MaintenanceEntity> existing = const [],
}) {
  final single = draft.items.length == 1;
  String? clean(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;
  return [
    for (final item in draft.items)
      () {
        final prior = existing.where((e) => e.key == item.key).firstOrNull;
        return MaintenanceEntity(
          id: prior?.id ?? newId(),
          bikeId: bikeId,
          serviceType: item.type,
          date: draft.date,
          odometerKm: draft.odometerKm,
          // One item: the bill is its price, whatever was stored before.
          cost: single ? (draft.totalCost ?? item.cost) : item.cost,
          notes: clean(draft.notes),
          customLabel: item.type == ServiceType.custom
              ? clean(item.customLabel)
              : null,
          createdAt: prior?.createdAt ?? now,
          visitId: visitId,
          checkKey: item.checkKey,
          shopName: clean(draft.shopName),
          shopKind: draft.shopKind,
          receiptPath: draft.receiptPath,
          visitTotal: single ? null : draft.totalCost,
          visitLabel: draft.visitLabel,
          partBrand: clean(item.partBrand),
          partGrade: clean(item.partGrade),
        );
      }(),
  ];
}
