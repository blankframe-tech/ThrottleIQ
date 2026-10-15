import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/maintenance_profile.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';

IconData _iconFor(PrecheckItem i) => switch (i) {
      PrecheckItem.tires => Icons.tire_repair,
      PrecheckItem.controls => Icons.tune,
      PrecheckItem.lights => Icons.lightbulb_outline,
      PrecheckItem.oil => Icons.opacity,
      PrecheckItem.chain => Icons.link,
      PrecheckItem.stands => Icons.vertical_align_bottom,
    };

/// A nudge card for the weekly 30-second T-CLOCS check (MSF pre-ride
/// inspection). Quiet when a check was done in the last week.
class PrecheckCard extends ConsumerWidget {
  final String bikeId;
  const PrecheckCard({super.key, required this.bikeId});

  static const nudgeAfterDays = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final last =
        ref.watch(maintenanceProfileProvider(bikeId)).valueOrNull?.lastPrecheckAt;
    final days = last == null ? null : DateTime.now().difference(last).inDays;
    final due = days == null || days >= nudgeAfterDays;

    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(14),
      borderColor: due ? context.palette.primary.withValues(alpha: 0.5) : null,
      onTap: () => PrecheckSheet.show(context, bikeId),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined,
              color: due ? context.palette.primary : context.palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.precheckTitle, style: display(context, 15, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(
                  days == null
                      ? l10n.precheckNever
                      : l10n.precheckLastDone(days),
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}

/// Six tiles; tap one that isn't right. Saving turns each failed tile into a
/// "Needs attention" item until it's marked fixed.
class PrecheckSheet extends ConsumerStatefulWidget {
  final String bikeId;
  const PrecheckSheet({super.key, required this.bikeId});

  static Future<void> show(BuildContext context, String bikeId) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.palette.surface,
        builder: (_) => PrecheckSheet(bikeId: bikeId),
      );

  @override
  ConsumerState<PrecheckSheet> createState() => _PrecheckSheetState();
}

class _PrecheckSheetState extends ConsumerState<PrecheckSheet> {
  final _failed = <PrecheckItem>{};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.precheckTitle, style: display(context, 20)),
            const SizedBox(height: 4),
            Text(l10n.precheckInstructions,
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                for (final item in PrecheckItem.values)
                  _Tile(
                    item: item,
                    failed: _failed.contains(item),
                    onTap: () => setState(() => _failed.contains(item)
                        ? _failed.remove(item)
                        : _failed.add(item)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('precheckSave'),
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        await ref
                            .read(precheckIssuesProvider(widget.bikeId).notifier)
                            .record(_failed.toList());
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: Text(_failed.isEmpty
                    ? l10n.precheckAllGood
                    : l10n.precheckSaveIssues(_failed.length)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final PrecheckItem item;
  final bool failed;
  final VoidCallback onTap;
  const _Tile({required this.item, required this.failed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = failed ? context.palette.danger : context.palette.success;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.shape.radiusMd),
          border: Border.all(color: failed ? color : context.palette.border),
          color: failed ? color.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Icon(_iconFor(item), size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(precheckLabel(item, l10n),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    failed ? l10n.precheckNeedsWork : precheckHint(item, l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: context.palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
