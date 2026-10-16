import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/cloud/sync_manager.dart';
import '../../../../core/database/daos/impact_event_dao.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/crash_detection_settings.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/num_cast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/impact_event_types.dart';
import '../../domain/entities/ride_entity.dart';

/// Pushes answers up soon after they're given. A provider so widget tests
/// can swap it for a no-op instead of building the Firebase-backed
/// SyncManager.
final impactSyncTriggerProvider = Provider<void Function()>(
    (ref) => () => unawaited(ref.read(syncManagerProvider).sync()));

/// After the ride: "Possible fall at 9:28 PM — did you fall?" for each
/// tier-1+ impact shadow mode saved on this ride and the rider hasn't
/// answered yet. Renders nothing when there is nothing to ask.
///
/// The answer labels the impact (ImpactEventDao.setLabel); a "Yes" asks two
/// optional follow-ups (injury, road surface). Labels are what turn shadow
/// mode into a detector that can be calibrated and measured.
class ImpactQuestionCard extends ConsumerStatefulWidget {
  const ImpactQuestionCard({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<ImpactQuestionCard> createState() => _ImpactQuestionCardState();
}

class _ImpactQuestionCardState extends ConsumerState<ImpactQuestionCard> {
  final _dao = ImpactEventDao();
  List<Map<String, Object?>>? _pending;
  Map<String, Object?>? _awaitingDetail;
  ImpactSeverity? _severity;
  RoadSurface? _surface;
  bool _thanks = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final rows = await _dao.pendingQuestions(widget.rideId);
    if (mounted) setState(() => _pending = rows);
  }

  Future<void> _answer(Map<String, Object?> row, ImpactLabel label,
      {Map<String, Object?>? detail}) async {
    final consent = await CrashResearchConsent.isEnabled();
    await _dao.setLabel(row['id']! as String,
        label: label, consent: consent, detail: detail);
    ref.read(impactSyncTriggerProvider)();
    if (!mounted) return;
    setState(() {
      _awaitingDetail = null;
      _severity = null;
      _surface = null;
      _thanks = true;
    });
    await _load();
  }

  /// "Yes" becomes `fall` for an unhurt walking-pace tumble and `crash`
  /// otherwise (crash-detection plan §9).
  ImpactLabel _yesLabel(Map<String, Object?> row) {
    final speed = asDoubleOrNull(row['speed_before_ms']) ?? 0;
    return _severity == ImpactSeverity.none && speed < 10 / 3.6
        ? ImpactLabel.fall
        : ImpactLabel.crash;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final awaiting = _awaitingDetail;
    if (awaiting != null) {
      return _card(context, _followUp(context, l10n, awaiting));
    }

    final pending = _pending;
    if (pending == null || pending.isEmpty) {
      return _thanks
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.impactThanks,
                  style: TextStyle(color: context.palette.textSecondary)),
            )
          : const SizedBox.shrink();
    }

    final row = pending.first;
    final at = DateTime.tryParse(row['at'] as String? ?? '')?.toLocal();
    final time = at == null
        ? ''
        : MaterialLocalizations.of(context)
            .formatTimeOfDay(TimeOfDay.fromDateTime(at));
    final answers = [
      (ImpactLabel.crash, l10n.impactAnswerYes),
      (ImpactLabel.phoneFell, l10n.impactAnswerPhoneFell),
      (ImpactLabel.bump, l10n.impactAnswerBump),
      (ImpactLabel.hardStop, l10n.impactAnswerHardStop),
      (ImpactLabel.unsure, l10n.impactAnswerUnsure),
    ];
    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.impactQuestionTitle(time),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.impactQuestionBody,
              style: TextStyle(color: context.palette.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final (label, text) in answers)
                OutlinedButton(
                  key: Key('impact_answer_${label.wire}'),
                  onPressed: () => label == ImpactLabel.crash
                      ? setState(() => _awaitingDetail = row)
                      : _answer(row, label),
                  child: Text(text),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _followUp(
      BuildContext context, AppLocalizations l10n, Map<String, Object?> row) {
    final severities = [
      (ImpactSeverity.none, l10n.impactSeverityNone),
      (ImpactSeverity.minor, l10n.impactSeverityMinor),
      (ImpactSeverity.medical, l10n.impactSeverityMedical),
    ];
    final surfaces = [
      (RoadSurface.paved, l10n.surfacePaved),
      (RoadSurface.broken, l10n.surfaceBroken),
      (RoadSurface.dirt, l10n.surfaceDirt),
      (RoadSurface.gravel, l10n.surfaceGravel),
      (RoadSurface.wet, l10n.surfaceWet),
      (RoadSurface.railCrossing, l10n.surfaceRailCrossing),
      (RoadSurface.speedBump, l10n.surfaceSpeedBump),
    ];
    Map<String, Object?> detail() => {
          if (_severity != null) 'severity': _severity!.wire,
          if (_surface != null) 'surface': _surface!.wire,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.impactFollowUpTitle,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.palette.textPrimary)),
        const SizedBox(height: 10),
        Text(l10n.impactSeverityLabel,
            style:
                TextStyle(fontSize: 13, color: context.palette.textSecondary)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final (s, text) in severities)
            ChoiceChip(
              label: Text(text),
              selected: _severity == s,
              onSelected: (on) => setState(() => _severity = on ? s : null),
            ),
        ]),
        const SizedBox(height: 10),
        Text(l10n.impactSurfaceLabel,
            style:
                TextStyle(fontSize: 13, color: context.palette.textSecondary)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final (s, text) in surfaces)
            ChoiceChip(
              label: Text(text),
              selected: _surface == s,
              onSelected: (on) => setState(() => _surface = on ? s : null),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          TextButton(
            onPressed: () => _answer(row, ImpactLabel.crash),
            child: Text(l10n.skip),
          ),
          const Spacer(),
          ElevatedButton(
            key: const Key('impact_follow_up_save'),
            onPressed: () => _answer(row, _yesLabel(row), detail: detail()),
            child: Text(l10n.impactSaveAnswer),
          ),
        ]),
      ],
    );
  }

  Widget _card(BuildContext context, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: EditorialCard(
          padding: const EdgeInsets.all(14),
          borderColor: context.palette.primary,
          child: child,
        ),
      );
}

/// Ride summary → "Report a crash or fall": the rider marks a fall the
/// detector missed. Without these, recall can't be measured (plan §11).
class ReportCrashButton extends ConsumerWidget {
  const ReportCrashButton({super.key, required this.ride});

  final RideEntity ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      key: const Key('report_crash_button'),
      onPressed: () async {
        final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _ReportCrashSheet(ride: ride),
        );
        if (saved == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.reportCrashSaved)));
        }
      },
      icon: const Icon(Icons.report_outlined, size: 18),
      label: Text(context.l10n.reportCrashAction),
    );
  }
}

class _ReportCrashSheet extends ConsumerStatefulWidget {
  const _ReportCrashSheet({required this.ride});

  final RideEntity ride;

  @override
  ConsumerState<_ReportCrashSheet> createState() => _ReportCrashSheetState();
}

class _ReportCrashSheetState extends ConsumerState<_ReportCrashSheet> {
  double _fraction = 0.5;
  List<Map<String, Object?>> _points = const [];
  ImpactSeverity? _severity;
  RoadSurface? _surface;
  bool _saving = false;

  DateTime get _start => widget.ride.startTime;
  DateTime get _end =>
      widget.ride.endTime ??
      _start.add(Duration(seconds: widget.ride.durationSeconds ?? 0));
  DateTime get _at => _start.add(Duration(
      milliseconds:
          (_end.difference(_start).inMilliseconds * _fraction).round()));

  @override
  void initState() {
    super.initState();
    unawaited(_prefill());
  }

  /// Starts the slider at the strongest impact the detector did log, if
  /// any: a missed fall usually still left a tier-0 trace.
  Future<void> _prefill() async {
    final points = await RidePointDao().getForRide(widget.ride.id);
    final events = await ImpactEventDao().getForRide(widget.ride.id);
    double? best;
    DateTime? bestAt;
    for (final e in events) {
      final g = asDoubleOrNull(e['peak_user_g']) ?? 0;
      final at = DateTime.tryParse(e['at'] as String? ?? '');
      if (at != null && (best == null || g > best)) {
        best = g;
        bestAt = at;
      }
    }
    if (!mounted) return;
    setState(() {
      _points = points;
      final span = _end.difference(_start).inMilliseconds;
      if (bestAt != null && span > 0) {
        _fraction =
            (bestAt.difference(_start).inMilliseconds / span).clamp(0.0, 1.0);
      }
    });
  }

  ({double lat, double lng})? _positionAt(DateTime at) {
    Map<String, Object?>? nearest;
    var bestGap = 1 << 62;
    for (final p in _points) {
      final t = DateTime.tryParse(p['timestamp'] as String? ?? '');
      if (t == null) continue;
      final gap = (t.difference(at).inMilliseconds).abs();
      if (gap < bestGap) {
        bestGap = gap;
        nearest = p;
      }
    }
    if (nearest == null) return null;
    return (lat: asDouble(nearest['lat']), lng: asDouble(nearest['lng']));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final at = _at;
    final pos = _positionAt(at);
    await ImpactEventDao().reportMissed(
      id: const Uuid().v4(),
      rideId: widget.ride.id,
      userId: widget.ride.userId,
      at: at,
      consent: await CrashResearchConsent.isEnabled(),
      placement: ref.read(phonePlacementProvider),
      lat: pos?.lat,
      lng: pos?.lng,
      detail: {
        if (_severity != null) 'severity': _severity!.wire,
        if (_surface != null) 'surface': _surface!.wire,
      },
    );
    ref.read(impactSyncTriggerProvider)();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(_at.toLocal()));
    final severities = [
      (ImpactSeverity.none, l10n.impactSeverityNone),
      (ImpactSeverity.minor, l10n.impactSeverityMinor),
      (ImpactSeverity.medical, l10n.impactSeverityMedical),
    ];
    final surfaces = [
      (RoadSurface.paved, l10n.surfacePaved),
      (RoadSurface.broken, l10n.surfaceBroken),
      (RoadSurface.dirt, l10n.surfaceDirt),
      (RoadSurface.gravel, l10n.surfaceGravel),
      (RoadSurface.wet, l10n.surfaceWet),
      (RoadSurface.railCrossing, l10n.surfaceRailCrossing),
      (RoadSurface.speedBump, l10n.surfaceSpeedBump),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.reportCrashTitle,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary)),
              const SizedBox(height: 4),
              Text(l10n.reportCrashBody,
                  style: TextStyle(color: context.palette.textSecondary)),
              const SizedBox(height: 12),
              Center(
                child: Text(time,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
              ),
              Slider(
                key: const Key('report_crash_time_slider'),
                value: _fraction,
                onChanged: (v) => setState(() => _fraction = v),
              ),
              Text(l10n.impactSeverityLabel,
                  style: TextStyle(
                      fontSize: 13, color: context.palette.textSecondary)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final (s, text) in severities)
                  ChoiceChip(
                    label: Text(text),
                    selected: _severity == s,
                    onSelected: (on) =>
                        setState(() => _severity = on ? s : null),
                  ),
              ]),
              const SizedBox(height: 10),
              Text(l10n.impactSurfaceLabel,
                  style: TextStyle(
                      fontSize: 13, color: context.palette.textSecondary)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final (s, text) in surfaces)
                  ChoiceChip(
                    label: Text(text),
                    selected: _surface == s,
                    onSelected: (on) =>
                        setState(() => _surface = on ? s : null),
                  ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancelAction),
                ),
                const Spacer(),
                ElevatedButton(
                  key: const Key('report_crash_save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.impactSaveAnswer),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
