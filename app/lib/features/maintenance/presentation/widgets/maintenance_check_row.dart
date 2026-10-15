import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/beta_testers.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/maintenance_profile.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import 'edit_maintenance_check_sheet.dart';
import '../../../../core/utils/parse_localized_number.dart';
import 'forecast_text.dart';
import 'order_part_sheet.dart';

/// Whether the signed-in rider sees the demo parts-order button.
final canOrderPartsProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  return BetaTesters.canOrderParts(profile?.username);
});

/// One tracked check: what's left in the rider's terms, why the interval
/// was adapted, and a thin wear bar. Tapping opens the part's detail.
class MaintenanceCheckRow extends ConsumerWidget {
  final CheckForecast forecast;
  final bool imperial;
  final String bikeId;

  const MaintenanceCheckRow({
    super.key,
    required this.forecast,
    required this.imperial,
    required this.bikeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = forecast;
    final l10n = context.l10n;
    final color = statusColor(context, f.status);
    final unknown = f.status == ReminderStatus.unknown;
    final emphasise = f.needsAttention;
    final canOrder = ref.watch(canOrderPartsProvider) &&
        f.needsAttention &&
        isOrderable(f.serviceType);

    return EditorialCard(
      key: Key('checkRow_${f.key}'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      borderColor: f.status == ReminderStatus.overdue
          ? context.palette.danger
          : context.palette.border,
      onTap: () => context.push(
          '/home/maintenance/check?bikeId=$bikeId&key=${Uri.encodeComponent(f.key)}'),
      child: Row(
        children: [
          Icon(iconForServiceType(f.serviceType),
              size: 20,
              color: emphasise ? color : context.palette.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(forecastLabel(f, l10n),
                    style: display(context, 15, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(
                  rowRemainingText(f, l10n, imperial),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: emphasise ? FontWeight.w700 : FontWeight.normal,
                    color: emphasise ? color : context.palette.textSecondary,
                  ),
                ),
                if (f.reasons.isNotEmpty || (f.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final r in f.reasons)
                        _Chip(adaptReasonLabel(r, l10n), icon: Icons.trending_down),
                      if ((f.notes ?? '').trim().isNotEmpty)
                        _Chip(f.notes!.trim(), icon: Icons.notes),
                    ],
                  ),
                ],
                if (!unknown) ...[
                  const SizedBox(height: 7),
                  EditorialProgress(f.progress.clamp(0.0, 1.0),
                      color: emphasise ? color : context.palette.textTertiary,
                      height: 4),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (unknown)
            TextButton(
              onPressed: () => SetLastDoneSheet.show(context,
                  bikeId: bikeId, checkKey: f.key, label: forecastLabel(f, l10n)),
              child: Text(l10n.setLastDone,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            )
          else ...[
            if (canOrder)
              IconButton(
                tooltip: l10n.partOrderButton,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.shopping_bag_outlined, size: 20, color: color),
                onPressed: () => OrderPartSheet.show(context, f.serviceType),
              ),
            IconButton(
              tooltip: l10n.log,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.add_task, size: 20, color: context.palette.primary),
              onPressed: () => context.push(
                  '/home/maintenance/add?bikeId=$bikeId&serviceType=${Uri.encodeComponent(f.key)}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.palette.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(context.shape.radiusSm),
        border: Border.all(color: context.palette.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: context.palette.textTertiary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: context.palette.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// A failed quick-check tile, shown with the due checks until it's fixed.
class PrecheckIssueRow extends ConsumerWidget {
  final PrecheckIssue issue;
  const PrecheckIssueRow({super.key, required this.issue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      borderColor: context.palette.attention,
      child: Row(
        children: [
          Icon(Icons.report_problem_outlined,
              size: 20, color: context.palette.attention),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(precheckLabel(issue.item, l10n),
                    style: display(context, 15, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(l10n.precheckIssueFlagged(shortDate(context, issue.createdAt)),
                    style: TextStyle(fontSize: 12, color: context.palette.attention)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(precheckIssuesProvider(issue.bikeId).notifier)
                .resolve(issue.id),
            child: Text(l10n.markFixed,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// "Set last done" for a check with nothing to count from: the odometer and
/// date it was last done (either may be unknown).
class SetLastDoneSheet extends ConsumerStatefulWidget {
  final String bikeId;
  final String checkKey;
  final String label;
  const SetLastDoneSheet(
      {super.key, required this.bikeId, required this.checkKey, required this.label});

  static Future<void> show(BuildContext context,
      {required String bikeId, required String checkKey, required String label}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      builder: (_) =>
          SetLastDoneSheet(bikeId: bikeId, checkKey: checkKey, label: label),
    );
  }

  @override
  ConsumerState<SetLastDoneSheet> createState() => _SetLastDoneSheetState();
}

class _SetLastDoneSheetState extends ConsumerState<SetLastDoneSheet> {
  final _kmCtrl = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _kmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setLastDoneTitle(widget.label), style: display(context, 18)),
          const SizedBox(height: 4),
          Text(l10n.setLastDoneHelper,
              style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
          const SizedBox(height: 14),
          TextField(
            controller: _kmCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.odometerAtThatTime,
              suffixText: l10n.distanceStatLabel,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.event, size: 18),
            label: Text(_date == null ? l10n.pickDateOptional : longDate(context, _date!)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final km = parseLocalizedNumber(_kmCtrl.text.trim(), min: 0, max: 2000000);
                if (km == null && _date == null) {
                  Navigator.of(context).pop();
                  return;
                }
                await ref
                    .read(maintenanceConfigProvider(widget.bikeId).notifier)
                    .setBaseline(widget.checkKey, km: km, date: _date);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(l10n.safeQrSaveAction),
            ),
          ),
        ],
      ),
    );
  }
}
