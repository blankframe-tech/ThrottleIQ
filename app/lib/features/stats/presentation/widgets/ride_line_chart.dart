import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Minimal single-series sparkline for the Rides tab.
///
/// It stays a sparkline — no grid, no border, no y-axis ladder — but it is no
/// longer a bare line with nothing to read off it. Three pieces of context,
/// and only three:
///
///  * a dot on the highest point, so the peak is findable at a glance;
///  * that peak's **value**, printed once on the y-axis side. A full axis
///    scale would be noise: on a 20-point series the only number a rider
///    wants is "how big did it get".
///  * the **dates** of the first and last ride in the window, under the ends
///    of the line.
///
/// Dates rather than ride indices on the x-axis: the series is chronological
/// but *irregularly spaced in time*, so "12 Jun → 1 Aug" tells the rider what
/// span the trend covers, while "1 → 20" only restates the point count they
/// can already see. Only the two ends are labelled, which is all a sparkline
/// can carry legibly at this width.
class RideLineChart extends StatelessWidget {
  final List<double> values;
  final Color? color;

  /// Start dates for [values], same order and length. When absent (or the
  /// wrong length) the x-axis falls back to ride numbers.
  final List<DateTime>? dates;

  /// Unit suffix for the peak label, e.g. 'km'.
  final String? unit;

  const RideLineChart({
    super.key,
    required this.values,
    this.color,
    this.dates,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    if (values.length < 2) {
      return SizedBox(
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

    // First index at the peak — with a repeated maximum, the earliest
    // occurrence is the one the eye lands on reading left to right.
    var peakIndex = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[peakIndex]) peakIndex = i;
    }

    // fl_chart lays left-axis ticks on multiples of `interval` counted from
    // zero — NOT from the chart's floor — so an interval of "floor to peak"
    // puts its ticks somewhere arbitrary. An interval of exactly the peak
    // guarantees a tick lands on it (0, peak, 2·peak; only `peak` is inside
    // the visible range), which is the one number this axis exists to show.
    // Everything else is filtered out below. A flat all-zero series gets no
    // label: the interval would be 0, which fl_chart asserts on, and "0" is
    // not worth the ink.
    final showPeakLabel = maxY > 0;
    final peakTolerance = maxY * 0.001 + 1e-9;

    final labels = _xLabels();

    return SizedBox(
      height: 132,
      child: LineChart(
        LineChartData(
          minY: lowerBound,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showPeakLabel,
                reservedSize: 46,
                interval: showPeakLabel ? maxY : null,
                getTitlesWidget: (value, meta) {
                  // Only the peak tick gets a label; float arithmetic lands
                  // it *near* maxY rather than exactly on it.
                  if ((value - maxY).abs() > peakTolerance) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      unit == null
                          ? _formatValue(maxY)
                          : '${_formatValue(maxY)} $unit',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: effectiveColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                // Ticks at the first and last point only.
                interval: (values.length - 1).toDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i != 0 && i != values.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i == 0 ? 0 : 1],
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              barWidth: 2.5,
              color: effectiveColor,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) => spot.x.round() == peakIndex,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3.5,
                  color: effectiveColor,
                  strokeWidth: 2,
                  strokeColor: AppColors.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: effectiveColor.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `[start, end]` labels for the x-axis.
  List<String> _xLabels() {
    final d = dates;
    if (d != null && d.length == values.length) {
      return [_formatDate(d.first), _formatDate(d.last)];
    }
    return ['Ride 1', 'Ride ${values.length}'];
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  /// Whole numbers stay whole; small values keep one decimal so a 0.8 km peak
  /// does not print as "1".
  static String _formatValue(double v) =>
      v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
