import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/calculators/fuel_units.dart';
import '../../domain/calculators/maintenance_money.dart';
import '../providers/maintenance_provider.dart';
import 'maintenance_format.dart';
import '../../../../core/i18n/numeric_locale.dart';

/// What the bike costs to run: ৳ per km (maintenance + fuel), the last six
/// months of service spend, and where the money went.
class MoneyCard extends ConsumerWidget {
  final String bikeId;
  final bool imperial;
  const MoneyCard({super.key, required this.bikeId, required this.imperial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(maintenanceMoneyProvider(bikeId)).valueOrNull;
    if (money == null || money.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final unit = imperial ? 'mi' : 'km';
    double rate(double perKm) =>
        imperial ? FuelUnits.costPerKmToPerMile(perKm) : perKm;
    final maxMonth = money.monthly
        .map((m) => m.amount)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialLabel(l10n.moneyTitle),
        const SizedBox(height: 10),
        EditorialCard(
          radius: context.shape.radiusLg,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCell(
                      value: money.totalPerKm == null
                          ? '—'
                          : '৳${formatTakaRate(rate(money.totalPerKm!))}',
                      label: l10n.costPerUnitLabel(unit),
                      align: CrossAxisAlignment.start,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      value: '৳${groupThousands(money.spend12m)}',
                      label: l10n.spentLast12Months,
                      align: CrossAxisAlignment.start,
                    ),
                  ),
                ],
              ),
              if (money.totalPerKm != null) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.perKmBreakdown(
                    money.maintenancePerKm == null
                        ? '—'
                        : '৳${formatTakaRate(rate(money.maintenancePerKm!))}',
                    money.fuelPerKm == null
                        ? '—'
                        : '৳${formatTakaRate(rate(money.fuelPerKm!))}',
                  ),
                  style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
                ),
              ],
              if (maxMonth > 0) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 110,
                  child: BarChart(
                    BarChartData(
                      maxY: maxMonth * 1.15,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => context.palette.ink,
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            '৳${groupThousands(rod.toY)}',
                            TextStyle(color: context.palette.onInk, fontSize: 11),
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= money.monthly.length) {
                                return const SizedBox.shrink();
                              }
                              final m = money.monthly[i];
                              return Text(
                                DateFormat.MMM(kNumericLocale).format(DateTime(m.year, m.month)),
                                style: TextStyle(
                                    fontSize: 10, color: context.palette.textTertiary),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < money.monthly.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: money.monthly[i].amount,
                              width: 16,
                              color: context.palette.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
              ],
              if (money.spend12m > 0) ...[
                const SizedBox(height: 12),
                for (final b in SpendBucket.values)
                  if ((money.split[b] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              switch (b) {
                                SpendBucket.oil => l10n.spendOil,
                                SpendBucket.parts => l10n.spendParts,
                                SpendBucket.visit => l10n.spendVisits,
                              },
                              style: TextStyle(
                                  fontSize: 12, color: context.palette.textSecondary),
                            ),
                          ),
                          Text('৳${groupThousands(money.split[b]!)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
