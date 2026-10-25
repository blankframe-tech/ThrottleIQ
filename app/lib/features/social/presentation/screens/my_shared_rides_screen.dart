import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../providers/ride_feed_provider.dart';
import '../widgets/shared_ride_list_card.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

/// The signed-in rider's own shared rides — reached from the garage header's
/// user menu (`garage_screen.dart`'s `_UserMenuButton`), mirroring
/// MyPlacesListScreen's pattern for a personal-content management list.
class MySharedRidesScreen extends ConsumerWidget {
  const MySharedRidesScreen({super.key});

  Future<void> _delete(
      BuildContext context, WidgetRef ref, String rideId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.surface,
        title: Text(ctx.l10n.deleteSharedRide),
        content: Text(ctx.l10n.thisRemovesItFrom),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(ctx.l10n.cancelAction)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ctx.l10n.delete,
                style: TextStyle(color: ctx.palette.danger)),
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
      appBar: AppBar(title: Text(context.l10n.mySharedRides)),
      body: ridesAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: context.palette.primary)),
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
                    Icon(Icons.ios_share,
                        size: 64, color: context.palette.textTertiary),
                    const SizedBox(height: 16),
                    Text(context.l10n.haventSharedAnyRides,
                        style: TextStyle(
                            color: context.palette.textSecondary,
                            fontSize: 16)),
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
                return SharedRideListCard(
                  ride: ride,
                  onDelete: () => _delete(context, ref, ride.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
