import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/fuel_economy.dart';
import '../../domain/entities/fuel_log.dart';
import '../providers/fuel_provider.dart';
import '../widgets/forecast_text.dart';
import '../widgets/maintenance_format.dart';

/// "1.25" / "12.5" — litres with no trailing zeros.
String formatLiters(double l) {
  final s = l.toStringAsFixed(l >= 10 ? 1 : 2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// One bike's fuel log: headline numbers, then every fill-up newest first.
/// Reached from the bike's Fuel card (bike detail) and the maintenance page.
class FuelScreen extends ConsumerWidget {
  final String bikeId;
  const FuelScreen({super.key, required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bike = (ref.watch(allBikesProvider).valueOrNull ??
            ref.watch(garageProvider).valueOrNull ??
            const [])
        .where((b) => b.id == bikeId)
        .firstOrNull;
    final logsAsync = ref.watch(fuelLogsProvider(bikeId));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(bike == null
            ? l10n.fuelLogTitle
            : '${l10n.fuelLogTitle} · ${bike.displayName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addFuelFab'),
        onPressed: () =>
            context.push('/home/maintenance/fuel/add?bikeId=$bikeId'),
        icon: const Icon(Icons.local_gas_station),
        label: Text(l10n.fuelAddTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: logsAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(fuelLogsProvider(bikeId)),
        ),
        data: (logs) {
          if (logs.isEmpty) return const _Empty();
          final summary = summarizeFuel(logs);
          final efficiency = kmPerLiterByFill(logs);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingMd, 8, AppDimensions.paddingMd, 96),
            children: [
              FuelSummaryCard(summary: summary),
              const SizedBox(height: 20),
              EditorialLabel(l10n.fuelFillCount(logs.length)),
              const SizedBox(height: 8),
              for (final log in logs) ...[
                FuelLogTile(
                  log: log,
                  kmPerLiter: efficiency[log.id],
                  onTap: () => context.push(
                      '/home/maintenance/fuel/add?bikeId=$bikeId&logId=${log.id}'),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_gas_station_outlined,
                size: 48, color: context.palette.textTertiary),
            const SizedBox(height: 12),
            Text(context.l10n.fuelEmptyTitle, style: display(context, 18)),
            const SizedBox(height: 6),
            Text(context.l10n.fuelEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: context.palette.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// The fuel headline: average and last km/L, spend, litres, ৳/km, ৳/L.
class FuelSummaryCard extends StatelessWidget {
  final FuelSummary summary;
  const FuelSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String kmpl(double? v) => v == null ? '—' : v.toStringAsFixed(1);
    final cells = <(String, String)>[
      (l10n.fuelAvgEfficiency, kmpl(summary.avgKmPerLiter)),
      (l10n.fuelLastEfficiency, kmpl(summary.lastKmPerLiter)),
      (l10n.fuelTotalSpent, '৳${groupThousands(summary.totalCost)}'),
      (l10n.fuelTotalLiters, formatLiters(summary.totalLiters)),
      (
        l10n.fuelCostPerKm,
        summary.costPerKm == null
            ? '—'
            : '৳${formatTakaRate(summary.costPerKm!)}'
      ),
      (
        l10n.fuelAvgPrice,
        summary.avgPricePerLiter == null
            ? '—'
            : '৳${formatTaka(summary.avgPricePerLiter!)}'
      ),
    ];
    return EditorialCard(
      key: const Key('fuelSummary'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final (label, value) in cells)
                  SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: display(context, 18)),
                        const SizedBox(height: 2),
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: context.palette.textSecondary)),
                      ],
                    ),
                  ),
              ],
            );
          }),
          if (summary.avgKmPerLiter == null) ...[
            const SizedBox(height: 10),
            Text(l10n.fuelNeedTwoFull,
                style: TextStyle(
                    fontSize: 12, color: context.palette.textTertiary)),
          ],
        ],
      ),
    );
  }
}

class FuelLogTile extends StatelessWidget {
  final FuelLogEntity log;

  /// km/L of the stretch this fill-up closed, if it closed one.
  final double? kmPerLiter;
  final VoidCallback onTap;

  const FuelLogTile({
    super.key,
    required this.log,
    required this.onTap,
    this.kmPerLiter,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final details = [
      '${formatLiters(log.liters)} L',
      '৳${formatTaka(log.pricePerLiter)}/L',
      '${groupThousands(log.odometerKm)} km',
      if (log.station != null) log.station!,
    ].join(' · ');
    return EditorialCard(
      key: Key('fuelTile_${log.id}'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.local_gas_station_outlined,
              size: 20, color: p.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(longDate(context, log.filledAt),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary)),
                  if (!log.fullTank) ...[
                    const SizedBox(width: 6),
                    EditorialPill(context.l10n.fuelPartial,
                        tone: PillTone.neutral, filled: false),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('৳${groupThousands(log.totalCost)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary)),
              if (kmPerLiter != null)
                Text('${kmPerLiter!.toStringAsFixed(1)} km/L',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.success)),
            ],
          ),
        ],
      ),
    );
  }
}
