import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/database/daos/auto_detection_dao.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/calculators/auto_ride_reconciler.dart';

class AutoDetectionHistorySheet extends StatefulWidget {
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
  State<AutoDetectionHistorySheet> createState() => _AutoDetectionHistorySheetState();
}

class _AutoDetectionHistorySheetState extends State<AutoDetectionHistorySheet> {
  late Future<List<Map<String, dynamic>>> _outcomesFuture;

  @override
  void initState() {
    super.initState();
    _outcomesFuture = AutoDetectionDao().recentOutcomes(limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              color: AppColors.border,
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
                        l10n.recentDetectionsTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.recentDetectionsSubtitle,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _outcomesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final outcomes = snapshot.data ?? [];
                if (outcomes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 40, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            l10n.recentDetectionsEmpty,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final dateFormat = DateFormat('MMM d, h:mm a');

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: outcomes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = outcomes[index];
                    final isReconciled = item['status'] == AutoDetectionStatus.reconciled;
                    final reason = item['discard_reason'] as String?;
                    final startedAtStr = item['started_at'] as String?;
                    final startedAt = startedAtStr != null
                        ? DateTime.tryParse(startedAtStr)
                        : null;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isReconciled
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.attention.withValues(alpha: 0.15),
                        child: Icon(
                          isReconciled ? Icons.check : Icons.info_outline,
                          size: 18,
                          color: isReconciled ? AppColors.primary : AppColors.attention,
                        ),
                      ),
                      title: Text(
                        isReconciled ? 'Ride Recorded' : _humanizeReason(l10n, reason),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        startedAt != null ? dateFormat.format(startedAt) : 'Unknown date',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isReconciled
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.border.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isReconciled ? 'SAVED' : 'DISCARDED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isReconciled ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
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

  String _humanizeReason(AppLocalizations l10n, String? reason) {
    switch (reason) {
      case ReconcileRejection.tooShortDistance:
        return l10n.rejectionTooShort;
      case ReconcileRejection.tooSlow:
        return l10n.rejectionTooSlow;
      case ReconcileRejection.tooFewFixes:
        return l10n.rejectionTooFewFixes;
      case ReconcileRejection.noMovement:
        return l10n.rejectionNoMovement;
      default:
        return 'Brief trip not classified as ride';
    }
  }
}
