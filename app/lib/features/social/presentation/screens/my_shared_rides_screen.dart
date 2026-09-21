import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../providers/ride_feed_provider.dart';
import '../../../../shared/widgets/error_view.dart';

const _audienceLabels = {
  'public': 'Public',
  'followers': 'Followers',
  'mutual': 'Mutual',
};

/// The signed-in rider's own shared rides — reached from the garage header's
/// user menu (`garage_screen.dart`'s `_UserMenuButton`), mirroring
/// MyPlacesListScreen's pattern for a personal-content management list.
class MySharedRidesScreen extends ConsumerWidget {
  const MySharedRidesScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, String rideId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.surface,
        title: const Text('Delete shared ride?'),
        content: const Text('This removes it from the feed for everyone. '
            'Your local ride history is unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: ctx.palette.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await RideShareRepository().deleteSharedRide(rideId);
    ref.invalidate(myRidesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(myRidesProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('My Shared Rides')),
      body: ridesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myRidesProvider),
        ),
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ios_share, size: 64, color: context.palette.textTertiary),
                    const SizedBox(height: 16),
                    Text("You haven't shared any rides yet",
                        style: TextStyle(color: context.palette.textSecondary, fontSize: 16)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myRidesProvider.future),
            color: context.palette.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              itemCount: rides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final ride = rides[i];
                return EditorialCard(
                  onTap: () => context.push('/rides/shared/${ride.id}', extra: ride),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(ride.bikeName, style: display(context, 16, letterSpacing: 0)),
                          ),
                          EditorialPill(
                            _audienceLabels[ride.audience] ?? ride.audience,
                            tone: PillTone.neutral,
                            filled: false,
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline,
                                color: context.palette.textTertiary, size: 18),
                            onPressed: () => _delete(context, ref, ride.id),
                          ),
                        ],
                      ),
                      Text(
                        '${_formatDate(ride.rideDate)} · ${ride.distanceKm.toStringAsFixed(1)} km · '
                        '${SpeedFormatter.durationFromSeconds(ride.durationSeconds)}',
                        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.mode_comment_outlined,
                              size: 14, color: context.palette.textTertiary),
                          const SizedBox(width: 4),
                          Text('${ride.comments}',
                              style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                          const SizedBox(width: 12),
                          Icon(Icons.arrow_upward, size: 14, color: context.palette.textTertiary),
                          const SizedBox(width: 4),
                          Text('${ride.netScore}',
                              style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
