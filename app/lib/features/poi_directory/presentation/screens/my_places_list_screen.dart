import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../providers/places_provider.dart';

/// Places the signed-in rider added themselves — reached from the garage
/// header's user menu (`garage_screen.dart`'s `_UserMenuButton`). Derived
/// from `PlaceEntity.createdBy` (a real Firestore query), not a spoofable
/// array on the profile.
class MyPlacesListScreen extends ConsumerWidget {
  const MyPlacesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(myPlacesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Places')),
      body: placesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (places) {
          if (places.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined, size: 64, color: AppColors.textTertiary),
                    SizedBox(height: 16),
                    Text("You haven't added any places yet",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myPlacesProvider.future),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              itemCount: places.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final place = places[i];
                return AppCard(
                  onTap: () => context.push('/home/places/${place.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(place.category.icon, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              place.verified
                                  ? '${place.category.displayName} · Verified'
                                  : place.category.displayName,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
}
