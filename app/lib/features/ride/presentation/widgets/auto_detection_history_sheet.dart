import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/calculators/daily_ride_summary.dart';
import '../providers/daily_ride_summary_provider.dart';
import '../../../../core/i18n/l10n_context.dart';

/// Auto-tracking's history, one row per day.
///
/// This used to list every background detection ("Ride recorded" /
/// "Discarded: too short"). In Dhaka traffic one commute came out as several
/// detections, so the list read as five rides where there was one. It now
/// shows the per-day summary instead — rides counted once per journey,
/// recorded and not-recorded together — and individual detections are no
/// longer surfaced anywhere. Their raw data is still kept locally.
class AutoDetectionHistorySheet extends ConsumerWidget {
  const AutoDetectionHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AutoDetectionHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = ref.watch(recentDailyRideSummariesProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dailySummariesTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.dailySummariesSubtitle,
                        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.close,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: days.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => _empty(context, l10n),
              data: (list) {
                if (list.isEmpty) return _empty(context, l10n);
                final dateFormat = DateFormat('EEE, MMM d');
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final day = list[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            context.palette.primary.withValues(alpha: 0.15),
                        child: Icon(Icons.motorcycle,
                            size: 18, color: context.palette.primary),
                      ),
                      title: Text(
                        '${dateFormat.format(day.day)} · '
                        '${l10n.autoSummaryRides(day.rideCount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: DailySummaryDetails(summary: day),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppDimensions.paddingMd),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 40, color: context.palette.textTertiary),
            const SizedBox(height: 12),
            Text(
              l10n.dailySummariesEmpty,
              style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The stats lines of one [DailyRideSummary]: distance, ride time and jam
/// time, plus how many rides weren't recorded. Shared by the history sheet
/// and the "Today" row of the auto-tracking tile.
class DailySummaryDetails extends StatelessWidget {
  const DailySummaryDetails({super.key, required this.summary});

  final DailyRideSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = TextStyle(fontSize: 12, color: context.palette.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.autoSummaryStats(
            (summary.distanceM / 1000).toStringAsFixed(1),
            summary.rideSeconds ~/ 60,
            summary.jamSeconds ~/ 60,
          ),
          style: style,
        ),
        if (summary.detectedRideCount > 0)
          Text(l10n.autoSummaryNotRecorded(summary.detectedRideCount),
              style: style),
      ],
    );
  }
}
