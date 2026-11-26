import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../ride/domain/entities/ride_entity.dart';

/// Km ridden on each of the last 7 days, oldest first, today last. A ride
/// counts on the day it started; rides before the window (or in the future)
/// are ignored.
List<double> simpleRidesKmPerDay(List<RideEntity> rides, DateTime now) {
  // UTC dates, so a DST day of 23 hours still counts as one day.
  final today = DateTime.utc(now.year, now.month, now.day);
  final km = List<double>.filled(7, 0);
  for (final r in rides) {
    final s = r.startTime;
    final ago = today.difference(DateTime.utc(s.year, s.month, s.day)).inDays;
    if (ago >= 0 && ago < 7) km[6 - ago] += r.distanceKm;
  }
  return km;
}

/// The Rides tab's one chart: km per day for the last 7 days. Plain bars, not
/// a stats-registry chart (Simple mode keeps its own widgets).
class SimpleRidesWeekBars extends StatelessWidget {
  const SimpleRidesWeekBars({super.key, required this.rides, this.now});

  final List<RideEntity> rides;

  /// Defaults to the current time; tests pin it.
  final DateTime? now;

  static const _barHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final end = now ?? DateTime.now();
    final km = simpleRidesKmPerDay(rides, end);
    final max = km.fold<double>(0, (m, v) => v > m ? v : m);
    final dayFormat = DateFormat('E', kNumericLocale);
    final days = [
      for (var i = 0; i < 7; i++)
        dayFormat.format(DateTime(end.year, end.month, end.day - (6 - i))),
    ];
    final summary = [
      for (var i = 0; i < 7; i++) '${days[i]} ${km[i].toStringAsFixed(0)} km',
    ].join(', ');

    return Semantics(
      container: true,
      label: l10n.simpleRidesWeekSemantics(summary),
      excludeSemantics: true,
      child: EditorialCard(
        radius: context.shape.radiusLg,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialLabel(l10n.simpleRidesWeekTitle),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(km[i].toStringAsFixed(0),
                              style: TextStyle(
                                  fontSize: 11, color: palette.textSecondary)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          key: Key('simpleRidesBar$i'),
                          height:
                              max == 0 ? 2 : 2 + (_barHeight - 2) * km[i] / max,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == 6 ? palette.primary : palette.secondary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(days[i],
                              style: TextStyle(
                                  fontSize: 11, color: palette.textTertiary)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
