import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/shared_ride_entity.dart';

const _audienceLabels = {
  'public': 'Public',
  'followers': 'Followers',
  'mutual': 'Mutual',
};

/// One shared ride as a compact list card: bike, audience, date/distance/
/// duration, comments and score. Tapping opens the ride. Used by My Shared
/// Rides (with [onDelete]) and the Shared rides list on a rider's profile.
class SharedRideListCard extends StatelessWidget {
  final SharedRideEntity ride;
  final VoidCallback? onDelete;
  const SharedRideListCard({super.key, required this.ride, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      onTap: () => context.push('/rides/shared/${ride.id}', extra: ride),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ride.bikeName,
                    style: display(context, 16, letterSpacing: 0)),
              ),
              EditorialPill(
                _audienceLabels[ride.audience] ?? ride.audience,
                tone: PillTone.neutral,
                filled: false,
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: context.l10n.delete,
                  icon: Icon(Icons.delete_outline,
                      color: context.palette.textTertiary, size: 18),
                  onPressed: onDelete,
                ),
            ],
          ),
          Text(
            '${_formatDate(ride.rideDate)} · ${ride.distanceKm.toStringAsFixed(1)} km · '
            '${SpeedFormatter.durationFromSeconds(ride.durationSeconds)}',
            style:
                TextStyle(fontSize: 12, color: context.palette.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.mode_comment_outlined,
                  size: 14, color: context.palette.textTertiary),
              const SizedBox(width: 4),
              Text('${ride.comments}',
                  style: TextStyle(
                      fontSize: 12, color: context.palette.textTertiary)),
              const SizedBox(width: 12),
              Icon(Icons.arrow_upward,
                  size: 14, color: context.palette.textTertiary),
              const SizedBox(width: 4),
              Text('${ride.netScore}',
                  style: TextStyle(
                      fontSize: 12, color: context.palette.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
