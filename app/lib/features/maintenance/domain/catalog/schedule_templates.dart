/// Per-model service schedules that seed a bike's tracked checks.
///
/// A new bike used to get one hard-coded km table whatever it was — a 110cc
/// commuter and a 160cc bike, air- or liquid-cooled, the same. Now setup
/// picks a [ScheduleTemplate] by brand/model (falling back to engine size),
/// and the rider can switch it. Every interval is still editable per check;
/// only checks whose interval came from a template ([IntervalSource.template])
/// are retuned when the template or the oil grade changes.
///
/// **Accuracy.** Only [verified] templates were checked against an owner's
/// manual (the source is named). The rest are approximate — assembled from
/// manufacturer service-coupon schedules and owner reports — and say so in
/// the UI. BD-market manuals can differ from the Indian ones these came from;
/// see DOCS/Handoff for agents and Todos/issues_open.md §95.
library;

import '../entities/maintenance_entity.dart';

/// One item's interval: whichever of [km] and [days] comes first.
class ItemSchedule {
  final double km;
  final int? days;
  const ItemSchedule(this.km, [this.days]);
}

/// A warranty free service: due by [maxKm] or [maxDays] from purchase,
/// whichever is first.
class FreeService {
  final double minKm;
  final double maxKm;
  final int? maxDays;
  const FreeService(this.minKm, this.maxKm, [this.maxDays]);
}

class ScheduleTemplate {
  /// Stable id, persisted on the bike's maintenance profile.
  final String id;

  /// Shown as-is (model names aren't translated).
  final String name;

  /// True only when the schedule was read off an owner's manual.
  final bool verified;

  /// Where the numbers came from, for the "about this schedule" note.
  final String? source;

  /// Overrides on top of each type's generic default
  /// ([ServiceTypeExt.defaultIntervalKm] / [ServiceTypeExt.defaultIntervalDays]).
  final Map<ServiceType, ItemSchedule> overrides;

  /// Checks turned on by default. Everything else starts off but can be
  /// enabled in "Customize checks".
  final Set<ServiceType> enabledByDefault;

  final List<FreeService> freeServices;

  /// Lower-case substrings matched against "brand model".
  final List<String> matchAny;

  /// Engine-size range this template is the fallback for (inclusive).
  final int? minCc;
  final int? maxCc;

  const ScheduleTemplate({
    required this.id,
    required this.name,
    this.verified = false,
    this.source,
    this.overrides = const {},
    required this.enabledByDefault,
    this.freeServices = const [],
    this.matchAny = const [],
    this.minCc,
    this.maxCc,
  });

  /// The interval for [type] under this template.
  ItemSchedule scheduleFor(ServiceType type) =>
      overrides[type] ?? ItemSchedule(type.defaultIntervalKm, type.defaultIntervalDays);

  bool get isGeneric => matchAny.isEmpty;
}

/// Engine-oil grades. In Bangladesh the oil change ("mobil change") is the
/// maintenance event that matters most, and how long a fill lasts depends
/// far more on the oil than on the bike — so the oil check's interval
/// follows the grade the rider actually uses.
///
/// Ranges from BikeBD's guide (mineral 1,000–1,500 km, semi-synthetic
/// 2,000–3,000, full synthetic 3,000–5,000, and at least every 6–12 months);
/// the values here sit in the conservative half of each range.
enum OilGrade { mineral, semiSynthetic, fullSynthetic }

extension OilGradeExt on OilGrade {
  ItemSchedule get schedule => switch (this) {
        OilGrade.mineral => const ItemSchedule(1500, 180),
        OilGrade.semiSynthetic => const ItemSchedule(2500, 240),
        OilGrade.fullSynthetic => const ItemSchedule(3500, 365),
      };

  static OilGrade? fromString(String? s) =>
      OilGrade.values.where((g) => g.name == s).firstOrNull;
}

/// Checks most bikes should track from day one.
const Set<ServiceType> _commonEnabled = {
  ServiceType.oilChange,
  ServiceType.chain,
  ServiceType.chainTension,
  ServiceType.tire,
  ServiceType.airFilter,
  ServiceType.sparkPlug,
  ServiceType.brakeFluid,
  ServiceType.battery,
};

const List<ScheduleTemplate> kScheduleTemplates = [
  // ── Model-specific ──────────────────────────────────────────────────────
  ScheduleTemplate(
    id: 'bajaj_pulsar_150',
    name: 'Bajaj Pulsar 150',
    verified: true,
    source: 'Bajaj Pulsar 150 owner\'s manual (BS-VI): free services at '
        '500–750 km / 30–45 days, 4,500–5,000 km / 240 days and '
        '9,500–10,000 km / 360 days, then every 5,000 km or 120 days.',
    matchAny: ['pulsar 150', 'pulsar150', 'pulsar n150', 'pulsar p150'],
    overrides: {
      // The manual allows 10,000 km on Bajaj's own long-life oil; most BD
      // riders use regular oil, so the grade picked in setup decides this.
      ServiceType.oilChange: ItemSchedule(2500, 120),
      ServiceType.airFilter: ItemSchedule(5000, 120),
      ServiceType.sparkPlug: ItemSchedule(10000, 365),
      ServiceType.valveClearance: ItemSchedule(10000),
      ServiceType.chain: ItemSchedule(500, 30),
      ServiceType.chainTension: ItemSchedule(1000, 30),
      ServiceType.frontDiscPads: ItemSchedule(5000, 120),
      ServiceType.rearDrumPads: ItemSchedule(5000, 120),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.valveClearance,
      ServiceType.frontDiscPads,
      ServiceType.rearDrumPads,
    },
    freeServices: [
      FreeService(500, 750, 45),
      FreeService(4500, 5000, 240),
      FreeService(9500, 10000, 360),
    ],
  ),
  ScheduleTemplate(
    id: 'honda_hornet_160',
    name: 'Honda CB Hornet 160R / Hornet 2.0',
    source: 'Approximate: Honda service coupons (about 4,000 km or 6 months) '
        'and owner reports of 2,500–3,000 km oil changes.',
    matchAny: ['hornet', 'cb hornet', 'cbf 160', 'x-blade', 'xblade'],
    overrides: {
      ServiceType.oilChange: ItemSchedule(2500, 180),
      ServiceType.airFilter: ItemSchedule(8000, 365),
      ServiceType.valveClearance: ItemSchedule(8000),
      ServiceType.frontDiscPads: ItemSchedule(8000),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.frontDiscPads,
      ServiceType.valveClearance,
    },
    freeServices: [
      FreeService(750, 1000, 30),
      FreeService(5500, 6000, 180),
      FreeService(11500, 12000, 365),
    ],
  ),
  ScheduleTemplate(
    id: 'yamaha_fz_v3',
    name: 'Yamaha FZ-S / FZ V3',
    source: 'Approximate: first service at 1,000 km, oil about every '
        '3,000–4,000 km per owner reports.',
    matchAny: ['fz', 'fzs', 'fz-s', 'fazer', 'saluto'],
    overrides: {
      ServiceType.oilChange: ItemSchedule(3000, 180),
      ServiceType.airFilter: ItemSchedule(8000, 365),
      ServiceType.valveClearance: ItemSchedule(10000),
      ServiceType.frontDiscPads: ItemSchedule(10000),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.frontDiscPads,
    },
    freeServices: [
      FreeService(500, 1000, 30),
    ],
  ),
  ScheduleTemplate(
    id: 'yamaha_r15',
    name: 'Yamaha R15 / MT-15',
    source: 'Approximate: liquid-cooled, synthetic-oil schedule per owner '
        'reports; coolant every 2 years.',
    matchAny: ['r15', 'r 15', 'mt15', 'mt-15', 'mt 15'],
    overrides: {
      ServiceType.oilChange: ItemSchedule(3500, 240),
      ServiceType.oilFilter: ItemSchedule(7000, 365),
      ServiceType.airFilter: ItemSchedule(10000, 365),
      ServiceType.radiatorCoolant: ItemSchedule(20000, 730),
      ServiceType.frontDiscPads: ItemSchedule(10000),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.oilFilter,
      ServiceType.radiatorCoolant,
      ServiceType.frontDiscPads,
    },
    freeServices: [
      FreeService(500, 1000, 30),
    ],
  ),
  ScheduleTemplate(
    id: 'suzuki_gixxer',
    name: 'Suzuki Gixxer',
    source: 'Approximate: first service at 1,000 km or 45 days with an oil '
        'change, oil about every 2,500–3,000 km per owner reports.',
    matchAny: ['gixxer', 'gsx'],
    overrides: {
      ServiceType.oilChange: ItemSchedule(2500, 180),
      ServiceType.oilFilter: ItemSchedule(5000, 365),
      ServiceType.airFilter: ItemSchedule(8000, 365),
      ServiceType.frontDiscPads: ItemSchedule(10000),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.oilFilter,
      ServiceType.frontDiscPads,
    },
    freeServices: [
      FreeService(750, 1000, 45),
    ],
  ),
  ScheduleTemplate(
    id: 'tvs_apache_160',
    name: 'TVS Apache RTR 160',
    source: 'Approximate: free services at 500 / 2,500 / 5,000 / 8,500 / '
        '11,500 km (owner reports); oil about every 2,500–3,000 km.',
    matchAny: ['apache'],
    overrides: {
      ServiceType.oilChange: ItemSchedule(2500, 180),
      ServiceType.airFilter: ItemSchedule(8000, 365),
      ServiceType.frontDiscPads: ItemSchedule(10000),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.frontDiscPads,
    },
    freeServices: [
      FreeService(400, 500, 30),
      FreeService(2000, 2500, 120),
      FreeService(4500, 5000, 210),
      FreeService(8000, 8500, 300),
      FreeService(11000, 11500, 365),
    ],
  ),

  // ── Generic, by engine size ─────────────────────────────────────────────
  ScheduleTemplate(
    id: 'generic_commuter',
    name: 'Commuter, up to 125cc',
    source: 'Approximate: typical air-cooled commuter schedule with mineral '
        'oil.',
    minCc: 0,
    maxCc: 125,
    overrides: {
      ServiceType.oilChange: ItemSchedule(1500, 180),
      ServiceType.airFilter: ItemSchedule(6000, 365),
      ServiceType.rearDrumPads: ItemSchedule(8000),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.rearDrumPads,
    },
  ),
  ScheduleTemplate(
    id: 'generic_mid',
    name: '126–200cc',
    source: 'Approximate: typical 150–165cc schedule with semi-synthetic oil.',
    minCc: 126,
    maxCc: 200,
    overrides: {
      ServiceType.oilChange: ItemSchedule(2500, 180),
      ServiceType.valveClearance: ItemSchedule(10000),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.frontDiscPads,
    },
  ),
  ScheduleTemplate(
    id: 'generic_large',
    name: 'Over 200cc',
    source: 'Approximate: liquid-cooled, synthetic-oil schedule.',
    minCc: 201,
    maxCc: 100000,
    overrides: {
      ServiceType.oilChange: ItemSchedule(4000, 365),
      ServiceType.oilFilter: ItemSchedule(8000, 365),
      ServiceType.airFilter: ItemSchedule(12000, 365),
      ServiceType.radiatorCoolant: ItemSchedule(20000, 730),
    },
    enabledByDefault: {
      ..._commonEnabled,
      ServiceType.oilFilter,
      ServiceType.radiatorCoolant,
      ServiceType.frontDiscPads,
    },
  ),
];

/// Used when nothing about the bike is known (no cc, no model match).
const String kDefaultTemplateId = 'generic_mid';

ScheduleTemplate templateById(String? id) =>
    kScheduleTemplates.where((t) => t.id == id).firstOrNull ??
    kScheduleTemplates.firstWhere((t) => t.id == kDefaultTemplateId);

/// The best template for a bike: a model match first, then engine size,
/// then [kDefaultTemplateId].
ScheduleTemplate suggestTemplate({
  required String brand,
  required String model,
  int? cc,
}) {
  final haystack = '$brand $model'.toLowerCase();
  for (final t in kScheduleTemplates) {
    if (t.matchAny.any(haystack.contains)) return t;
  }
  if (cc != null && cc > 0) {
    for (final t in kScheduleTemplates) {
      if (t.isGeneric &&
          t.minCc != null &&
          t.maxCc != null &&
          cc >= t.minCc! &&
          cc <= t.maxCc!) {
        return t;
      }
    }
  }
  return templateById(kDefaultTemplateId);
}

/// The configs a fresh setup writes for [bikeId] under [template]: every
/// built-in type, enabled per the template, intervals from the template (and
/// the oil grade, when known).
List<MaintenanceConfigEntity> configsFromTemplate({
  required String bikeId,
  required ScheduleTemplate template,
  OilGrade? oilGrade,
}) {
  return [
    for (final type in ServiceType.values)
      if (type != ServiceType.custom)
        () {
          final schedule = (type == ServiceType.oilChange && oilGrade != null)
              ? oilGrade.schedule
              : template.scheduleFor(type);
          return MaintenanceConfigEntity(
            bikeId: bikeId,
            serviceType: type,
            intervalKm: schedule.km,
            intervalDays: schedule.days,
            isEnabled: type == ServiceType.fuel
                ? false
                : template.enabledByDefault.contains(type),
          );
        }(),
  ];
}

/// Re-applies [template] (and [oilGrade]) to [current], changing only the
/// intervals of checks the rider hasn't set by hand. Enabled flags, notes,
/// baselines and custom checks are kept.
List<MaintenanceConfigEntity> retuneToTemplate({
  required List<MaintenanceConfigEntity> current,
  required ScheduleTemplate template,
  OilGrade? oilGrade,
}) {
  return [
    for (final c in current)
      if (c.isCustom || c.source == IntervalSource.user)
        c
      else
        () {
          final schedule =
              (c.serviceType == ServiceType.oilChange && oilGrade != null)
                  ? oilGrade.schedule
                  : template.scheduleFor(c.serviceType);
          return c.copyWith(
            intervalKm: schedule.km,
            intervalDays: schedule.days,
            clearIntervalDays: schedule.days == null,
          );
        }(),
  ];
}

/// One-tap groups in "Log a visit": the jobs a mechanic usually does
/// together, so a whole servicing is one entry instead of six.
enum ServiceBundle { oilChange, generalService, chainCare, brakeService }

extension ServiceBundleExt on ServiceBundle {
  List<ServiceType> get types => switch (this) {
        ServiceBundle.oilChange => const [
            ServiceType.oilChange,
            ServiceType.oilFilter,
          ],
        // Mirrors a BD service-centre "servicing" (e.g. Yamaha's 10-point
        // Expert Care check).
        ServiceBundle.generalService => const [
            ServiceType.oilChange,
            ServiceType.oilFilter,
            ServiceType.airFilter,
            ServiceType.chain,
            ServiceType.chainTension,
            ServiceType.sparkPlug,
            ServiceType.frontDiscPads,
            ServiceType.rearDrumPads,
            ServiceType.clutchCable,
            ServiceType.throttleCables,
            ServiceType.tire,
          ],
        ServiceBundle.chainCare => const [
            ServiceType.chain,
            ServiceType.chainTension,
          ],
        ServiceBundle.brakeService => const [
            ServiceType.frontDiscPads,
            ServiceType.rearDrumPads,
            ServiceType.brakeFluid,
          ],
      };
}
