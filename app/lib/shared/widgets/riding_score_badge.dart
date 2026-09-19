import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/riding_score.dart';
import '../../l10n/app_localizations.dart';

/// Gamified riding-score card: a big tier-colored number plus a tier label,
/// so it reads as a rank the rider earned rather than another stat tile.
///
/// Extracted from the social shared-ride-detail screen so a private ride's
/// own summary can use the same treatment instead of a flat black number
/// tile — see `DOCS/Handoff for agents and Todos/issues_fixed.md` for the
/// "why does the social ride detail look cooler" note this closed.
class RidingScoreBadge extends StatelessWidget {
  final int score;

  const RidingScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tier = ridingScoreTier(score);
    final (color, label, icon) = switch (tier) {
      RidingScoreTier.smooth => (AppColors.success, l10n.scoreSmoothLabel, Icons.emoji_events),
      RidingScoreTier.steady => (AppColors.attention, l10n.scoreSteadyLabel, Icons.thumb_up_alt_rounded),
      RidingScoreTier.aggressive => (AppColors.danger, l10n.scoreAggressiveLabel, Icons.warning_amber_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(
            '$score',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color, height: 1),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('/100', style: TextStyle(fontSize: 13, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.ridingScoreLabel,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Icon(icon, color: color, size: 26),
        ],
      ),
    );
  }
}
