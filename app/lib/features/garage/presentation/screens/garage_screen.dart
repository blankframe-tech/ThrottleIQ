import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/garage_provider.dart';
import '../../domain/entities/bike_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bikesAsync = ref.watch(garageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: "Your Garage" + user menu
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 12,
                  AppDimensions.paddingMd, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Your Garage', style: display(28))),
                  const _UserMenuButton(),
                ],
              ),
            ),
            Expanded(
              child: bikesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: AppColors.danger))),
                data: (bikes) {
                  if (bikes.isEmpty) return const _EmptyGarage();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 4,
                        AppDimensions.paddingMd, AppDimensions.paddingLg),
                    itemCount: bikes.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => i < bikes.length
                        ? _BikeCard(bike: bikes[i])
                        : DashedAddButton(
                            label: 'Add a bike',
                            onTap: () => context.go('/home/garage/add'),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar/menu button in the garage header — replaces the old round "+"
/// (add-bike moved below the bike list). Opens the signed-in rider's own
/// menu: profile edit today, with room for Epic E to add "My places".
class _UserMenuButton extends ConsumerWidget {
  const _UserMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;

    return GestureDetector(
      onTap: () => _showMenu(context),
      child: UserAvatar(
        photoUrl: profile?.photoUrl ?? user?.photoURL,
        name: profile?.bestName ?? user?.displayName ?? 'Rider',
        radius: 22,
      ),
    );
  }

  // Pops with the destination path as the sheet's result rather than
  // popping-then-pushing inline: a Navigator.pop immediately followed by a
  // context.push in the same synchronous callback races the sheet's
  // imperative route removal against go_router's declarative page-list
  // update on the same Navigator, which can produce two pages computing
  // the same key -- Flutter's Navigator._updatePages assertion
  // "'!keyReservation.contains(key)': is not true." (confirmed crash site:
  // this exact menu, tapping "My Places"). Awaiting the sheet's own Future
  // and pushing only after it fully resolves guarantees the sheet's route
  // is completely gone before anything else touches the Navigator.
  Future<void> _showMenu(BuildContext context) async {
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text('Edit Profile'),
              onTap: () => Navigator.pop(sheetContext, '/profile/edit'),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined, color: AppColors.primary),
              title: const Text('My Places'),
              onTap: () => Navigator.pop(sheetContext, '/places/mine'),
            ),
          ],
        ),
      ),
    );
    if (destination != null && context.mounted) context.push(destination);
  }
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.garage_outlined, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No bikes yet', style: display(20)),
            const SizedBox(height: 6),
            const Text('Add your first bike to get started',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
            const SizedBox(height: 20),
            DashedAddButton(
              label: 'Add a bike',
              onTap: () => context.go('/home/garage/add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BikeCard extends ConsumerWidget {
  final BikeEntity bike;
  const _BikeCard({required this.bike});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditorialCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/home/garage/${bike.id}'),
      borderColor: bike.isActive ? AppColors.primary : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo strip placeholder
          Stack(
            children: [
              Container(
                height: 116,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusXl)),
                ),
                child: const Center(
                  child: Icon(Icons.two_wheeler, size: 44, color: AppColors.textTertiary),
                ),
              ),
              if (bike.isActive)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: EditorialPill('Active', tone: PillTone.accent),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(bike.displayName, style: display(18, letterSpacing: 0)),
                    ),
                    if (!bike.isActive)
                      TextButton(
                        onPressed: () =>
                            ref.read(garageProvider.notifier).setActiveBike(bike.id),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(60, 32)),
                        child: const Text('Set active', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                if (bike.cc != null)
                  Text('${bike.cc}cc',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatCell(
                        value: SpeedFormatter.distanceKm(bike.totalDistanceM),
                        label: 'total',
                        valueSize: 18,
                      ),
                    ),
                    Expanded(
                      child: StatCell(value: '${bike.rideCount}', label: 'rides', valueSize: 18),
                    ),
                    Expanded(
                      child: StatCell(
                        value: bike.lastRideAt != null
                            ? '${DateTime.now().difference(bike.lastRideAt!).inDays}d'
                            : '—',
                        label: 'last ride',
                        valueSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.go('/home/maintenance?bikeId=${bike.id}'),
                  child: Row(
                    children: [
                      Text('Tap for maintenance',
                          style: display(14,
                              letterSpacing: 0, color: AppColors.primary)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
