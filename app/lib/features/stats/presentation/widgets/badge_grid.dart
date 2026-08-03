import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/badges.dart';
import '../../../../shared/widgets/editorial.dart';

/// The Rides tab's badge shelf.
///
/// One tile per badge *family* rather than one per badge: the ladders share
/// an icon by design (five distance rungs are the same achievement at five
/// sizes), so 38 individual tiles would be the same ten glyphs repeated with
/// no added meaning. The tile carries the family's highest earned tier and
/// its earned count; tapping opens the full ladder, where every rung is
/// listed with its own state and its own explanation — what it means if it's
/// earned, what to do about it if it isn't.
class BadgeGrid extends StatelessWidget {
  final List<BadgeFamilyProgress> families;

  const BadgeGrid({super.key, required this.families});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final family in families)
          _BadgeFamilyTile(
            progress: family,
            onTap: () => showBadgeLadderSheet(context, family),
          ),
      ],
    );
  }
}

/// Opens the ladder for one family. Public so a future "badge earned" toast
/// can reuse exactly the same sheet.
Future<void> showBadgeLadderSheet(
  BuildContext context,
  BadgeFamilyProgress progress,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
    ),
    builder: (_) => _BadgeLadderSheet(progress: progress),
  );
}

class _BadgeFamilyTile extends StatelessWidget {
  final BadgeFamilyProgress progress;
  final VoidCallback onTap;

  const _BadgeFamilyTile({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final earned = progress.earnedCount > 0;
    final color = earned ? AppColors.primary : AppColors.textTertiary;
    final tier = progress.highestTier;

    return Semantics(
      button: true,
      label: '${progress.family.name}, '
          '${progress.earnedCount} of ${progress.badges.length} earned',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: SizedBox(
          width: 78,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: earned
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusLg),
                  border: Border.all(
                    color: earned ? AppColors.primary : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: Icon(progress.family.icon, size: 24, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                progress.family.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: earned
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // Single-rung families ("First ride") have no ladder to
                // report progress along, so they just say earned or not.
                progress.badges.length == 1
                    ? (earned ? 'Earned' : 'Locked')
                    : (tier == null
                        ? '0/${progress.badges.length}'
                        : '${tier.label} · ${progress.earnedCount}/${progress.badges.length}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.2,
                  color: earned ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeLadderSheet extends StatelessWidget {
  final BadgeFamilyProgress progress;

  const _BadgeLadderSheet({required this.progress});

  @override
  Widget build(BuildContext context) {
    final family = progress.family;
    final next = progress.nextUp;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd,
            AppDimensions.paddingMd, AppDimensions.paddingMd,
            AppDimensions.paddingLg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(family.icon,
                      size: 26,
                      color: progress.earnedCount > 0
                          ? AppColors.primary
                          : AppColors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(family.name,
                        style: display(20, letterSpacing: 0)),
                  ),
                  Text('${progress.earnedCount}/${progress.badges.length}',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(family.about,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Text(
                'You: ${formatBadgeValue(progress.value)} ${family.unit}',
                style: display(15, letterSpacing: 0),
              ),
              if (next != null) ...[
                const SizedBox(height: 8),
                EditorialProgress(
                  (progress.value / next.def.threshold)
                      .clamp(0.0, 1.0)
                      .toDouble(),
                ),
                const SizedBox(height: 6),
                Text(
                  'Next: ${next.def.name} — '
                  '${formatBadgeValue(next.def.threshold - progress.value)} '
                  '${family.unit} to go',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text('Every tier earned. Nothing left to chase here.',
                    style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
              const SizedBox(height: 18),
              const EditorialLabel('Tiers'),
              const SizedBox(height: 10),
              for (final badge in progress.badges) ...[
                _LadderRow(progress: progress, badge: badge),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  final BadgeFamilyProgress progress;
  final EarnedBadge badge;

  const _LadderRow({required this.progress, required this.badge});

  @override
  Widget build(BuildContext context) {
    final family = progress.family;
    final earned = badge.earned;
    final color = earned ? AppColors.primary : AppColors.textTertiary;

    return EditorialCard(
      padding: const EdgeInsets.all(12),
      borderColor: earned ? AppColors.primary : AppColors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(earned ? family.icon : Icons.lock_outline, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(badge.def.name,
                          style: display(14, letterSpacing: 0)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      badge.def.tier.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  // Earned rungs explain what the badge *is*; locked ones
                  // explain what to do about it, with the gap spelled out so
                  // "how far off am I" never needs mental arithmetic.
                  earned
                      ? 'Earned. ${family.requirementFor(badge.def.threshold)}'
                      : '${family.requirementFor(badge.def.threshold)} '
                          "You're at ${formatBadgeValue(progress.value)} "
                          'of ${formatBadgeValue(badge.def.threshold)} '
                          '${family.unit}.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
