import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/bug_report_sheet.dart';
import '../../data/utils/geohash_utils.dart';
import '../../domain/entities/place_entity.dart';
import '../providers/places_provider.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../place_category_l10n.dart';

/// Places bottom-nav tab: nearby garages/fuel pumps/parts shops/biker cafes
/// and other recreation stops, filterable by category, with an "Add place"
/// entry point and a manual "Import nearby" action that pulls those POIs
/// from OpenStreetMap.
class PlacesListScreen extends ConsumerStatefulWidget {
  const PlacesListScreen({super.key});

  @override
  ConsumerState<PlacesListScreen> createState() => _PlacesListScreenState();
}

class _PlacesListScreenState extends ConsumerState<PlacesListScreen> {
  PlaceCategory? _selectedCategory;
  bool _importing = false;

  Future<void> _importNearby() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final count = await importNearbyOsmPlaces(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 0
              ? context.l10n.noNewPlacesFound
              : context.l10n.importedPlaces(count)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotImportNearby(e))),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // Invalidates nearbyPlacesProvider only after AddPlaceScreen's route has
  // fully popped (context.push's future resolves once the whole route,
  // including its exit transition, is gone) rather than racing this
  // screen's list-swap against that route's removal in the same frame —
  // see AddPlaceScreen._submit's doc comment for why a same-tick "pop then
  // invalidate" reorder alone isn't a strong enough guarantee.
  Future<void> _addPlace(BuildContext context) async {
    final added = await context.push<bool>('/home/places/add');
    if (added == true) {
      ref.invalidate(nearbyPlacesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(nearbyPlacesProvider(_selectedCategory));
    final positionAsync = ref.watch(currentPositionProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(context.l10n.navPlacesLabel),
        actions: [
          IconButton(
            tooltip: context.l10n.importNearbyPlacesFrom,
            icon: _importing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary),
                  )
                : const Icon(Icons.travel_explore_outlined),
            onPressed: _importing ? null : _importNearby,
          ),
        ],
      ),
      body: Stack(
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
                    label: context.l10n.allFilter,
                    icon: '📍',
                    selected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  for (final category in PlaceCategory.values)
                    _CategoryChip(
                      label: category.localizedName(context.l10n),
                      icon: category.icon,
                      selected: _selectedCategory == category,
                      onTap: () => setState(() => _selectedCategory = category),
                    ),
                ],
              ),
            ),
            // Routes live under Places because both answer "where should I
            // ride?" — one as a destination, the other as the road there. It
            // navigates rather than filters, so it's a distinct, full-width
            // button below the chips instead of a chip that looked like one
            // more filter (grill §3.2.5).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingMd, AppDimensions.paddingMd, AppDimensions.paddingMd, 0),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/routes'),
                icon: const Icon(Icons.route, size: 18),
                label: Text(context.l10n.browseRoutes),
              ),
            ),
            Expanded(
              child: placesAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: context.palette.primary)),
                error: (e, _) {
                  final isServiceOff = isLocationServicesError(e);
                  final isPermissionDenied = isLocationPermissionError(e);
                  final isLocationIssue = isServiceOff || isPermissionDenied;
                  final message = isLocationIssue
                      ? mapLocationError(e, context.l10n)
                      : mapFirestoreError(e, context.l10n);

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLocationIssue
                                ? Icons.location_off_outlined
                                : Icons.error_outline_rounded,
                            size: 48,
                            color: context.palette.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isServiceOff)
                            ElevatedButton.icon(
                              onPressed: () => Geolocator.openLocationSettings(),
                              icon: const Icon(Icons.location_on_outlined, size: 18),
                              label: Text(context.l10n.turnOnLocation),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.palette.primary,
                                foregroundColor: Colors.white,
                              ),
                            )
                          else if (isPermissionDenied)
                            ElevatedButton.icon(
                              onPressed: () => Geolocator.openAppSettings(),
                              icon: const Icon(Icons.settings_outlined, size: 18),
                              label: Text(context.l10n.openSettings),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.palette.primary,
                                foregroundColor: Colors.white,
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: () {
                                ref.invalidate(currentPositionProvider);
                                ref.invalidate(nearbyPlacesProvider(_selectedCategory));
                              },
                              child: Text(context.l10n.tryAgain),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => BugReportSheet.show(context),
                            icon: const Icon(Icons.bug_report_outlined, size: 16),
                            label: Text(context.l10n.reportProblem),
                            style: TextButton.styleFrom(
                              foregroundColor: context.palette.textTertiary,
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (places) {
                  if (places.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_outlined, size: 64, color: context.palette.textTertiary),
                            const SizedBox(height: 16),
                            Text(context.l10n.noPlacesNearbyYet,
                                style: TextStyle(color: context.palette.textSecondary, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.addGarageFuelPump,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.palette.textTertiary, fontSize: 14),
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
                    color: context.palette.primary,
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
            onPressed: () => _addPlace(context),
            backgroundColor: context.palette.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(context.l10n.addPlaceLower, style: const TextStyle(color: Colors.white)),
          ),
        ),
      ],
      ),
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
          color: selected ? context.palette.primary.withValues(alpha: 0.15) : context.palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusFull),
          border: Border.all(color: selected ? context.palette.primary : context.palette.border),
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
                color: selected ? context.palette.primary : context.palette.textSecondary,
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
      onTap: () => context.push('/home/places/${place.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.primary.withValues(alpha: 0.1),
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
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  distanceKm == null
                      ? place.category.localizedName(context.l10n)
                      : '${place.category.localizedName(context.l10n)} · ${SpeedFormatter.distanceKm(distanceKm * 1000)}',
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Official points (checkposts, cameras) are not rated at all, so
              // they show no rating row; a place nobody has rated says so in
              // words instead of a lone "★ —" that reads as a rendering bug.
              if (place.category != PlaceCategory.police &&
                  place.category != PlaceCategory.aiCamera)
                if (place.hasGoogleRating || place.hasThrottleIqRating)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: context.palette.warning),
                      const SizedBox(width: 2),
                      Text(
                        place.dualRatingDisplay,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary),
                      ),
                    ],
                  )
                else
                  Text(
                    context.l10n.noRatingsYet,
                    style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
                  ),
              const SizedBox(height: 2),
              Text(
                (place.category == PlaceCategory.police || place.category == PlaceCategory.aiCamera)
                    ? context.l10n.officialPoint
                    : (place.hasAnyReviews
                        ? place.reviewsSummarySubtitle
                        : context.l10n.noReviewsYet),
                style: TextStyle(fontSize: 10, color: context.palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
