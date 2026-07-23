import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../providers/garage_provider.dart';
import '../../domain/entities/bike_entity.dart';
import '../../../forums/data/repositories/forum_repository.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';

class BikeDetailScreen extends ConsumerWidget {
  final String bikeId;
  const BikeDetailScreen({super.key, required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bikes = ref.watch(garageProvider).valueOrNull ?? [];
    final bike = bikes.where((b) => b.id == bikeId).firstOrNull;
    final ridesAsync = ref.watch(rideHistoryProvider(bikeId));

    if (bike == null) {
      return const Scaffold(
        body: Center(child: Text('Bike not found', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(bike.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Discuss this bike',
            onPressed: () => _openForum(context, bike),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/home/garage/$bikeId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image / header
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(color: AppColors.border),
                image: bike.imagePath != null
                    ? DecorationImage(
                        image: FileImage(File(bike.imagePath!)),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: bike.imagePath == null
                  ? const Icon(Icons.two_wheeler, size: 72, color: AppColors.textTertiary)
                  : null,
            ),
            const SizedBox(height: 16),

            // Stats grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                StatCard(
                  label: 'Total Distance',
                  value: bike.totalDistanceKm.toStringAsFixed(1),
                  unit: 'km',
                  icon: Icons.route,
                  isPrimary: true,
                ),
                StatCard(
                  label: 'Total Rides',
                  value: '${bike.rideCount}',
                  icon: Icons.flag_outlined,
                  valueColor: AppColors.primaryHighlight,
                  isPrimary: true,
                ),
                if (bike.odometerKm != null)
                  StatCard(
                    label: 'Odometer',
                    value: bike.currentOdometerKm.toStringAsFixed(0),
                    unit: 'km',
                    icon: Icons.speed_outlined,
                  ),
                if (bike.cc != null)
                  StatCard(label: 'Engine', value: '${bike.cc}', unit: 'cc', icon: Icons.settings),
                if (bike.year != null)
                  StatCard(label: 'Year', value: '${bike.year}', icon: Icons.calendar_today_outlined),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openForum(context, bike),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Discuss this bike'),
              ),
            ),
            const SizedBox(height: 24),

            // Ride history
            const Text('Ride History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ridesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
              data: (rides) {
                if (rides.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No rides yet for this bike',
                          style: TextStyle(color: AppColors.textTertiary)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final ride = rides[i];
                    return Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: InkWell(
                        onTap: () => context.push('/ride/summary/${ride.id}'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(ride.startTime),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${SpeedFormatter.distanceKm(ride.distanceM)} · ${SpeedFormatter.durationFromSeconds(ride.durationSeconds ?? 0)}',
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryHighlight,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForum(BuildContext context, BikeEntity bike) async {
    try {
      final forum = await ForumRepository().getOrCreateForum(brand: bike.brand, model: bike.model);
      if (!context.mounted) return;
      context.push('/forums/${forum.id}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open forum: $e')),
      );
    }
  }

  // Pops with a bool result rather than popping-then-navigating inline: a
  // Navigator.pop immediately followed by a context.go/push in the same
  // synchronous callback races the dialog's imperative route removal
  // against go_router's declarative page-list update on the same
  // Navigator, which can produce two pages computing the same key —
  // Flutter's Navigator._updatePages assertion
  // "'!keyReservation.contains(key)': is not true." Awaiting the dialog's
  // own Future and navigating only after it fully resolves (mirroring
  // active_ride_screen.dart's stop-ride confirm, already safe) guarantees
  // the dialog's route is completely gone before anything else touches
  // the Navigator.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Bike?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'All ride history for this bike will be deleted.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(garageProvider.notifier).deleteBike(bikeId);
      if (context.mounted) context.go('/home/garage');
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
