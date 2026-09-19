import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/ride_entity.dart';
import '../providers/auto_tracking_provider.dart';
import '../providers/ride_recording_provider.dart';
import 'bike_picker_card.dart';

/// Lets a rider fix a wrong bike pick right after finishing a ride.
///
/// Deliberately scoped to only the ride they just finished
/// ([latestCompletedRideIdProvider]), not any ride in history: an older
/// ride's bike may already be the basis for maintenance reminders someone has
/// acted on, so a general "edit any past ride" control would invite silently
/// rewriting stats far from where the mis-tap happened. "I picked the wrong
/// bike" is a mistake caught within the next ride or two, not months later.
///
/// Hidden when [BikeConfirmationCard] is already showing for this ride (an
/// auto-detected ride still awaiting its first confirmation) — that card is
/// the more prominent, purpose-built control for that case, and showing both
/// would just be two ways to do the same thing.
class ChangeBikeControl extends ConsumerWidget {
  const ChangeBikeControl({super.key, required this.ride});

  final RideEntity ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ride.isAuto && ride.bikeConfidence.needsConfirmation) {
      return const SizedBox.shrink();
    }

    final bikes = ref.watch(garageProvider).valueOrNull ?? const <BikeEntity>[];
    if (bikes.length < 2) return const SizedBox.shrink();

    final latestId = ref.watch(latestCompletedRideIdProvider).valueOrNull;
    if (latestId != ride.id) return const SizedBox.shrink();

    BikeEntity? currentBike;
    for (final bike in bikes) {
      if (bike.id == ride.bikeId) {
        currentBike = bike;
        break;
      }
    }
    if (currentBike == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () => _pickBike(context, ref, bikes, currentBike!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.two_wheeler, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.loggedToBikeLabel(currentBike.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.changeAction.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.primary),
              ),
              Icon(Icons.expand_more, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickBike(
    BuildContext context,
    WidgetRef ref,
    List<BikeEntity> bikes,
    BikeEntity currentBike,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingMd, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(l10n.changeBikeSheetTitle,
                          style: display(16, letterSpacing: 0))),
                ],
              ),
            ),
            for (final bike in bikes)
              ListTile(
                onTap: () => Navigator.pop(sheetContext, bike.id),
                title: BikeRow(
                  bike: bike,
                  subtitle: l10n.rideCountLabel(bike.rideCount),
                  trailing: bike.id == currentBike.id
                      ? Icon(Icons.check, size: 18, color: AppColors.primary)
                      : null,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || picked == currentBike.id) return;
    await ref.read(rideAttributionProvider).confirm(ride: ride, bikeId: picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.bikeConfirmationUpdatedMessage)),
    );
  }
}
