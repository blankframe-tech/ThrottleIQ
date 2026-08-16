import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/ride_entity.dart';
import '../providers/auto_tracking_provider.dart';

/// Asks which bike an auto-detected ride was on.
///
/// Shown on the ride summary for rides where the app guessed — see
/// [BikeAttributionConfidence]. Renders nothing for manually started rides,
/// for single-bike riders (where "the active bike" was never a guess), and for
/// rides already confirmed, so it costs nothing on the common path.
///
/// This is the visible half of the fix for silent misattribution: the app is
/// allowed to guess, but it is not allowed to guess *quietly*, because the
/// guess feeds distance-based maintenance reminders on two bikes at once.
class BikeConfirmationCard extends ConsumerWidget {
  const BikeConfirmationCard({super.key, required this.ride});

  final RideEntity ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ride.isAuto || !ride.bikeConfidence.needsConfirmation) {
      return const SizedBox.shrink();
    }

    final bikes = ref.watch(garageProvider).valueOrNull ?? const [];
    if (bikes.length <= 1) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.bikeConfirmationTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.bikeConfirmationBody,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final bike in bikes)
                ChoiceChip(
                  label: Text('${bike.brand} ${bike.model}'),
                  selected: bike.id == ride.bikeId,
                  onSelected: (_) => _confirm(context, ref, bike.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    String bikeId,
  ) async {
    await ref.read(rideAttributionProvider).confirm(ride: ride, bikeId: bikeId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).bikeConfirmationUpdatedMessage)),
    );
  }
}
