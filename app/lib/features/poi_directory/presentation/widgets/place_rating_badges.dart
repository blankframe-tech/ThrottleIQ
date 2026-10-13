import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/entities/place_entity.dart';

/// The two reputations side by side, each labelled with where it comes from:
/// `🏍 ★ 4.8 (24 riders)` for ThrottleIQ riders, `G ★ 4.4 (110 Google)` for
/// Google, plus a "Rider Approved" pill when [PlaceEntity.isRiderApproved].
///
/// Replaces the old "★ 4.2 + 4.8", which read like arithmetic and never said
/// which number was whose. Riders' rating comes first: it's the one that
/// knows about bike parking and whether the mechanic can read an EFI code.
class PlaceRatingBadges extends StatelessWidget {
  final PlaceEntity place;

  /// Hides the "no ratings yet" line — the carousel card is short on room.
  final bool showEmpty;

  /// One horizontally-scrolling row instead of wrapping — for fixed-height
  /// cards, where a second line of badges would overflow.
  final bool singleLine;

  const PlaceRatingBadges({
    super.key,
    required this.place,
    this.showEmpty = true,
    this.singleLine = false,
  });

  @override
  Widget build(BuildContext context) {
    if (place.category.isSafetyPoint) {
      return _Pill(
        icon: Icons.shield_outlined,
        label: context.l10n.officialPoint,
        color: context.palette.danger,
      );
    }
    if (!place.hasThrottleIqRating && !place.hasGoogleRating) {
      if (!showEmpty) return const SizedBox.shrink();
      return Text(
        context.l10n.noRatingsYet,
        style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
      );
    }
    final badges = <Widget>[
        if (place.isRiderApproved)
          Tooltip(
            message: context.l10n.placeRiderApprovedHint,
            child: _Pill(
              icon: Icons.verified,
              label: context.l10n.placeRiderApproved,
              color: context.palette.success,
              filled: true,
            ),
          ),
        if (place.hasThrottleIqRating)
          _Pill(
            icon: Icons.two_wheeler,
            label: context.l10n.placeRiderRatingBadge(
              place.averageRating.toStringAsFixed(1),
              place.ratingCount,
            ),
            color: context.palette.primary,
          ),
        if (place.hasGoogleRating)
          _Pill(
            leading: 'G',
            label: context.l10n.placeGoogleRatingBadge(
              place.googleRating.toStringAsFixed(1),
              place.googleRatingCount,
            ),
            color: context.palette.textSecondary,
          ),
    ];
    if (singleLine) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, badge) in badges.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              badge,
            ],
          ],
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: badges,
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String? leading;
  final String label;
  final Color color;
  final bool filled;

  const _Pill({
    this.icon,
    this.leading,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(context.shape.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 12, color: color),
          if (leading != null)
            Text(leading!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: filled ? color : context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
