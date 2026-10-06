import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/places_query.dart';
import '../providers/places_provider.dart';
import '../providers/saved_places_provider.dart';
import 'place_card.dart';
import 'places_status_views.dart';

/// The hub's Saved tab: the rider's bookmarks (local, so it works with no
/// signal) plus the way in to the places they've contributed — "My places"
/// used to be reachable only from the garage header's user menu, nowhere
/// near where riders browse places.
class SavedPlacesTab extends ConsumerWidget {
  const SavedPlacesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPlacesProvider);
    // Distance is a bonus here, never a requirement: a missing fix (or GPS
    // off) just leaves the cards without a distance.
    final position = ref.watch(currentPositionProvider).valueOrNull;

    final contributed = AppCard(
      onTap: () => context.push('/places/mine'),
      child: Row(
        children: [
          Icon(Icons.add_location_alt_outlined, color: context.palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.placesAddedByMe,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.savedPlacesContributedBody,
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textTertiary),
        ],
      ),
    );

    return savedAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(savedPlacesProvider)),
      data: (saved) {
        final hits = [
          for (final place in saved)
            toHit(place, originLat: position?.latitude, originLng: position?.longitude),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMd,
            AppDimensions.paddingMd,
            AppDimensions.paddingMd,
            AppDimensions.paddingXl + 56,
          ),
          children: [
            contributed,
            const SizedBox(height: 12),
            if (hits.isEmpty)
              PlacesStatusPanel(
                icon: Icons.bookmark_border,
                title: context.l10n.savedPlacesEmptyTitle,
                body: context.l10n.savedPlacesEmptyBody,
              )
            else
              for (final hit in hits) ...[
                PlaceCard(key: ValueKey('saved-${hit.place.id}'), hit: hit),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}
