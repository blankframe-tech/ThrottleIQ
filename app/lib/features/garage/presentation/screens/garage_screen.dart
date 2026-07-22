import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../providers/garage_provider.dart';
import '../../domain/entities/bike_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
            // Header: "Your Garage" + logout + ink add button
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 12,
                  AppDimensions.paddingMd, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Your Garage', style: display(28))),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20, color: AppColors.textSecondary),
                    tooltip: 'Sign out',
                    onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
                  ),
                  const SizedBox(width: 4),
                  _InkAddButton(onTap: () => context.go('/home/garage/add')),
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
                    itemCount: bikes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _BikeCard(bike: bikes[i]),
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

class _InkAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InkAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.add, color: AppColors.onInk, size: 24),
        ),
      ),
    );
  }
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.garage_outlined, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text('No bikes yet', style: display(20)),
          const SizedBox(height: 6),
          const Text('Tap + to add your first bike',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
        ],
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
                  onTap: () => context.go('/home/maintenance'),
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
