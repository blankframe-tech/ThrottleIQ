import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/utils/geohash_utils.dart';
import '../../domain/entities/place_entity.dart';
import '../providers/places_provider.dart';

/// Places tab inside SocialScreen: nearby garages/fuel pumps/parts shops,
/// filterable by category, with an "Add place" entry point.
class PlacesListScreen extends ConsumerStatefulWidget {
  const PlacesListScreen({super.key});

  @override
  ConsumerState<PlacesListScreen> createState() => _PlacesListScreenState();
}

class _PlacesListScreenState extends ConsumerState<PlacesListScreen> {
  PlaceCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(nearbyPlacesProvider(_selectedCategory));
    final positionAsync = ref.watch(currentPositionProvider);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingMd,
                AppDimensions.paddingMd,
                AppDimensions.paddingMd,
                0,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryChip(
                    label: 'All',
                    icon: '📍',
                    selected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  for (final category in PlaceCategory.values)
                    _CategoryChip(
                      label: category.displayName,
                      icon: category.icon,
                      selected: _selectedCategory == category,
                      onTap: () => setState(() => _selectedCategory = category),
                    ),
                ],
              ),
            ),
            Expanded(
              child: placesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingLg),
                    child: Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
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
                            Text('No places nearby yet',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                            SizedBox(height: 8),
                            Text(
                              'Add a garage, fuel pump, or parts shop to help other riders.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final position = positionAsync.valueOrNull;
                  return RefreshIndicator(
                    onRefresh: () {
                      ref.invalidate(currentPositionProvider);
                      return ref.refresh(nearbyPlacesProvider(_selectedCategory).future);
                    },
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.paddingMd,
                        AppDimensions.paddingMd,
                        AppDimensions.paddingMd,
                        // Extra bottom padding so the last card isn't hidden
                        // behind the floating "Add place" button.
                        AppDimensions.paddingXl + 56,
                      ),
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final place = places[i];
                        final distanceKm = position == null
                            ? null
                            : GeohashUtils.calculateDistance(
                                lat1: position.latitude,
                                lng1: position.longitude,
                                lat2: place.latitude,
                                lng2: place.longitude,
                              );
                        return _PlaceCard(place: place, distanceKm: distanceKm);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: AppDimensions.paddingMd,
          bottom: AppDimensions.paddingMd,
          child: FloatingActionButton.extended(
            heroTag: 'add_place_fab',
            onPressed: () => context.push('/places/add'),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add place', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PlaceEntity place;
  final double? distanceKm;

  const _PlaceCard({required this.place, required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final distanceKm = this.distanceKm;
    return AppCard(
      onTap: () => context.push('/places/${place.id}'),
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
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  distanceKm == null
                      ? place.category.displayName
                      : '${place.category.displayName} · ${SpeedFormatter.distanceKm(distanceKm * 1000)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text(
                    place.ratingCount == 0 ? '—' : place.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${place.ratingCount} review${place.ratingCount == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
