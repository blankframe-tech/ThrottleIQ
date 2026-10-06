import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/riding_conditions.dart';
import '../../domain/catalog/schedule_templates.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/forecast_text.dart';
import '../widgets/maintenance_format.dart';

/// Maintenance setup for one bike: which schedule it follows, how it's
/// ridden, and — the one question that matters most — when the oil was last
/// changed. Replaces the old "pick 8 checks" first-run cards, which counted
/// every item from 0 km and so lit a used bike up red on day one (§94.3).
class MaintenanceSetupScreen extends ConsumerStatefulWidget {
  final String bikeId;
  final bool firstTime;
  const MaintenanceSetupScreen(
      {super.key, required this.bikeId, this.firstTime = false});

  @override
  ConsumerState<MaintenanceSetupScreen> createState() =>
      _MaintenanceSetupScreenState();
}

class _MaintenanceSetupScreenState
    extends ConsumerState<MaintenanceSetupScreen> {
  ScheduleTemplate? _template;
  RidingProfile _riding = RidingProfile.normal;
  OilGrade? _grade;
  final _oilKmCtrl = TextEditingController();
  DateTime? _oilDate;
  bool _oilUnknown = false;
  bool _othersSame = false;
  bool _resetIntervals = false;
  bool _saving = false;
  bool _initialised = false;

  @override
  void dispose() {
    _oilKmCtrl.dispose();
    super.dispose();
  }

  void _initFrom() {
    if (_initialised) return;
    final bike = ref
        .read(garageProvider)
        .valueOrNull
        ?.where((b) => b.id == widget.bikeId)
        .firstOrNull;
    final profileAsync = ref.read(maintenanceProfileProvider(widget.bikeId));
    if (bike == null || !profileAsync.hasValue) return;
    final profile = profileAsync.value;
    _initialised = true;
    _template = profile?.onboardedAt != null
        ? profile!.template
        : suggestTemplate(brand: bike.brand, model: bike.model, cc: bike.cc);
    _riding = profile?.ridingProfile ?? RidingProfile.normal;
    _grade = profile?.oilGrade;
  }

  Future<void> _save() async {
    final template = _template;
    if (template == null) return;
    setState(() => _saving = true);
    final km = _oilUnknown ? null : double.tryParse(_oilKmCtrl.text.trim());
    final date = _oilUnknown ? null : _oilDate;
    await ref
        .read(maintenanceProfileProvider(widget.bikeId).notifier)
        .completeSetup(MaintenanceSetupDraft(
          template: template,
          ridingProfile: _riding,
          oilGrade: _grade,
          lastOilKm: km,
          lastOilDate: date,
          othersAtSameService: _othersSame && (km != null || date != null),
          resetIntervals: _resetIntervals,
        ));
    // Setup is the moment "we'll remind you when the oil is due" makes
    // sense, so the permission is asked here rather than at launch.
    try {
      await NotificationService.instance.requestPermissions();
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'Maintenance setup: notification permission');
    }
    if (!mounted) return;
    context.go('/home/maintenance?bikeId=${widget.bikeId}');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(maintenanceProfileProvider(widget.bikeId));
    _initFrom();
    final l10n = context.l10n;
    final bike = ref
        .watch(garageProvider)
        .valueOrNull
        ?.where((b) => b.id == widget.bikeId)
        .firstOrNull;
    final customized =
        ref.watch(isMaintenanceCustomizedProvider(widget.bikeId)).valueOrNull ??
            false;
    final template = _template;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: bike == null || template == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              children: [
                Text(bike.displayName, style: display(context, 22)),
                Text(distLabelLong(bike.currentOdometerKm, false),
                    style: TextStyle(color: context.palette.textSecondary)),
                const SizedBox(height: 20),

                // 1. Schedule
                EditorialLabel(l10n.setupScheduleLabel),
                const SizedBox(height: 8),
                EditorialCard(
                  radius: context.shape.radiusLg,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(template.name,
                                style: display(context, 16, letterSpacing: 0)),
                          ),
                          EditorialPill(
                            template.verified
                                ? l10n.scheduleVerified
                                : l10n.scheduleApproximate,
                            tone: template.verified
                                ? PillTone.ok
                                : PillTone.neutral,
                          ),
                        ],
                      ),
                      if (template.source != null) ...[
                        const SizedBox(height: 6),
                        Text(template.source!,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: context.palette.textSecondary)),
                      ],
                      if (template.freeServices.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.freeServicesSummary(template.freeServices.length),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        for (var i = 0; i < template.freeServices.length; i++)
                          Text(
                            '${i + 1}. ${groupThousands(template.freeServices[i].minKm)}–'
                            '${groupThousands(template.freeServices[i].maxKm)} km'
                            '${template.freeServices[i].maxDays != null ? ' · ${l10n.daysShort(template.freeServices[i].maxDays!)}' : ''}',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: context.palette.textSecondary),
                          ),
                      ],
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _pickTemplate,
                          child: Text(l10n.changeAction),
                        ),
                      ),
                    ],
                  ),
                ),
                if (customized) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _resetIntervals,
                    onChanged: (v) => setState(() => _resetIntervals = v),
                    title: Text(l10n.setupResetIntervals,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(l10n.setupResetIntervalsHelper,
                        style: const TextStyle(fontSize: 11.5)),
                  ),
                ],
                const SizedBox(height: 20),

                // 2. Roads
                EditorialLabel(l10n.setupRoadsLabel),
                const SizedBox(height: 8),
                for (final p in RidingProfile.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChoiceCard(
                      selected: _riding == p,
                      title: ridingProfileLabel(p, l10n),
                      subtitle: p == RidingProfile.normal
                          ? l10n.ridingProfileNormalHelper
                          : l10n.ridingProfileSevereHelper,
                      onTap: () => setState(() => _riding = p),
                    ),
                  ),
                Text(l10n.setupTelemetryNote,
                    style: TextStyle(
                        fontSize: 11.5, color: context.palette.textTertiary)),
                const SizedBox(height: 20),

                // 3. Oil
                EditorialLabel(l10n.setupOilLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in OilGrade.values)
                      ChoiceChip(
                        label: Text(oilGradeLabel(g, l10n)),
                        selected: _grade == g,
                        onSelected: (_) => setState(() => _grade = g),
                      ),
                    ChoiceChip(
                      label: Text(l10n.notSure),
                      selected: _grade == null,
                      onSelected: (_) => setState(() => _grade = null),
                    ),
                  ],
                ),
                if (_grade != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.oilGradeInterval(
                        groupThousands(_grade!.schedule.km),
                        _grade!.schedule.days ?? 0),
                    style: TextStyle(
                        fontSize: 11.5, color: context.palette.textSecondary),
                  ),
                ],
                const SizedBox(height: 14),
                Text(l10n.setupLastOilQuestion,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (!_oilUnknown) ...[
                  TextField(
                    key: const Key('setupOilKm'),
                    controller: _oilKmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.odometerAtThatTime,
                      hintText: bike.currentOdometerKm.toStringAsFixed(0),
                      suffixText: l10n.distanceStatLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(_oilDate == null
                        ? l10n.pickDateOptional
                        : longDate(context, _oilDate!)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _oilDate = picked);
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _othersSame,
                    onChanged: (v) => setState(() => _othersSame = v),
                    title: Text(l10n.setupOthersSame,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _oilUnknown,
                  onChanged: (v) => setState(() => _oilUnknown = v ?? false),
                  title: Text(l10n.setupOilUnknown,
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('setupSave'),
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(l10n.setupSave,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _pickTemplate() async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<ScheduleTemplate>(
      context: context,
      backgroundColor: context.palette.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.setupScheduleLabel, style: display(ctx, 18)),
            ),
            for (final t in kScheduleTemplates)
              ListTile(
                title: Text(t.name),
                subtitle: Text(t.verified
                    ? l10n.scheduleVerified
                    : l10n.scheduleApproximate),
                trailing: t.id == _template?.id
                    ? Icon(Icons.check, color: ctx.palette.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _template = picked);
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(12),
      borderColor: selected ? context.palette.primary : null,
      onTap: onTap,
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? context.palette.primary
                  : context.palette.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: context.palette.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
