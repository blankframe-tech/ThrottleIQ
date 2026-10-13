import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'maintenance_format.dart';
import 'running_costs_sheet.dart';

/// "What did this ride cost?" — distance × the bike's running cost per km,
/// broken down by fuel and each tracked check that has cost data.
///
/// Renders nothing while its sources load or for a zero-distance ride; with
/// no cost data at all it shows a one-line hint that opens the running-cost
/// settings in place.
class RideCostCard extends ConsumerWidget {
  final String bikeId;
  final double distanceKm;

  const RideCostCard({
    super.key,
    required this.bikeId,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bikeId.isEmpty || !(distanceKm > 0)) return const SizedBox.shrink();
    final breakdown =
        ref.watch(rideCostProvider((bikeId: bikeId, distanceKm: distanceKm)));
    if (breakdown == null) return const SizedBox.shrink();
    final l10n = context.l10n;

    if (breakdown.isEmpty) {
      return EditorialCard(
        radius: context.shape.radiusLg,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.payments_outlined,
                size: 20, color: context.palette.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.rideCostHint,
                  style: TextStyle(
                      fontSize: 12, color: context.palette.textSecondary)),
            ),
            TextButton(
              onPressed: () => RunningCostsSheet.show(context, bikeId),
              child: Text(l10n.rideCostSetUp),
            ),
          ],
        ),
      );
    }

    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(14),
      onTap: () => RunningCostsSheet.show(context, bikeId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: EditorialLabel(l10n.rideCostTitle)),
              Text('৳${formatTaka(breakdown.total)}',
                  key: const Key('rideCostTotal'),
                  style: display(context, 22)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.rideCostEstimateNote(distanceKm.toStringAsFixed(1),
                formatTakaRate(breakdown.costPerKm)),
            style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
          ),
          const SizedBox(height: 10),
          for (final line in breakdown.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(line.serviceType.localizedLabel(l10n),
                        style: TextStyle(
                            fontSize: 13,
                            color: context.palette.textSecondary)),
                  ),
                  Text('৳${formatTaka(line.cost)}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
