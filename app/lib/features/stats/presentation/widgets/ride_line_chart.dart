import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Minimal single-series line chart for the Rides tab — no axis chrome
/// beyond padding around the value range, styled to sit inside an
/// [EditorialCard] alongside a header/unit label the caller supplies.
class RideLineChart extends StatelessWidget {
  final List<double> values;
  final Color color;

  const RideLineChart({
    super.key,
    required this.values,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Not enough rides yet',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ),
      );
    }

    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    double pad = (maxY - minY) * 0.15;
    if (pad < 1.0) pad = 1.0;
    final lowerBound = minY - pad < 0 ? 0.0 : minY - pad;

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          minY: lowerBound,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              barWidth: 2.5,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
