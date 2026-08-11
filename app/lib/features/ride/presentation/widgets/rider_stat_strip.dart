import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../stats/presentation/providers/rider_stats_provider.dart';

/// Rides / distance / current streak, in one line under the Record hero.
///
/// These three numbers used to live on the bike card as chips and were then
/// moved off the screen entirely, on the reasoning that Record is for
/// starting rides and Rides is for looking back. That's right about *history*
/// — a list of past rides doesn't belong here — but wrong about these three:
/// they're the reason to go out again, which is exactly what this screen is
/// for. They're rendered as a flat strip rather than cards so they read as
/// context for the hero above, not as three things to tap.
///
/// Renders zeros rather than a spinner while the stats resolve: the layout is
/// fixed-height either way, and a progress indicator sliding into a strip of
/// numbers is more visually disruptive than a number that ticks up a moment
/// later.
class RiderStatStrip extends ConsumerWidget {
  const RiderStatStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(riderStatsProvider).valueOrNull;
    final streak = stats == null ? 0 : computeCurrentDayStreak(stats.allRides);
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        _Stat(value: '${stats?.totalRides ?? 0}', label: l10n.ridesStatLabel),
        const _Divider(),
        _Stat(
            value: _groupedKm(stats?.totalDistanceKm ?? 0),
            label: l10n.kilometresStatLabel),
        const _Divider(),
        _Stat(value: '$streak', label: l10n.dayStreakStatLabel),
      ],
    );
  }

  /// Whole kilometres, thousands-grouped. Four unbroken digits in a 22pt
  /// display face is exactly the number a rider has to stop and parse.
  static String _groupedKm(double km) {
    final digits = km.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.border);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: display(22, letterSpacing: -1)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
