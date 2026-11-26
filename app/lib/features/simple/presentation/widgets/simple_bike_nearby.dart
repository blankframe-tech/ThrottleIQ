import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../poi_directory/domain/entities/place_entity.dart';
import '../../../poi_directory/domain/place_directions.dart';
import '../../../poi_directory/domain/places_query.dart';
import '../../../poi_directory/presentation/providers/places_provider.dart';
import '../../../poi_directory/presentation/widgets/place_launch_actions.dart';

/// Search radius for the Bike tab's Find nearby.
const simpleBikeNearbyRadiusKm = 15.0;

/// Fuel stations and mechanics near the rider, nearest first, with Call and
/// Directions. Loads only when tapped, so opening the Bike tab asks for no
/// location and reads nothing from Firestore.
class SimpleBikeNearby extends ConsumerStatefulWidget {
  const SimpleBikeNearby({super.key});

  @override
  ConsumerState<SimpleBikeNearby> createState() => _SimpleBikeNearbyState();
}

class _SimpleBikeNearbyState extends ConsumerState<SimpleBikeNearby> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialLabel(l10n.simpleBikeNearbyTitle),
        const SizedBox(height: 8),
        if (!_open)
          OutlinedButton.icon(
            key: const Key('simpleBikeFindNearby'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
            onPressed: () => setState(() => _open = true),
            icon: const Icon(Icons.near_me_outlined),
            label: Text(l10n.simpleBikeNearbyAction),
          )
        else
          _results(context, l10n),
      ],
    );
  }

  Widget _results(BuildContext context, AppLocalizations l10n) {
    final position = ref.watch(currentPositionProvider);
    final places = ref.watch(nearbyPlacesProvider(simpleBikeNearbyRadiusKm));
    // A retry keeps the old error until it settles; show the spinner meanwhile.
    final error = position.isLoading || places.isLoading
        ? null
        : position.error ?? places.error;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errorText(error, l10n)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('simpleBikeNearbyRetry'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              ref.invalidate(currentPositionProvider);
              ref.invalidate(nearbyPlacesProvider(simpleBikeNearbyRadiusKm));
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      );
    }
    final pos = position.valueOrNull;
    final all = places.valueOrNull;
    if (pos == null || all == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    List<PlaceHit> nearest(PlaceCategory category) => (all
            .where((p) => p.category == category)
            .map((p) =>
                toHit(p, originLat: pos.latitude, originLng: pos.longitude))
            .toList()
          ..sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0)))
        .take(10)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (category, title) in [
          (PlaceCategory.fuel, l10n.simpleBikeNearbyFuel),
          (PlaceCategory.garage, l10n.simpleBikeNearbyGarage),
        ]) ...[
          const SizedBox(height: 8),
          Text(title, style: display(context, 16)),
          ..._list(context, l10n, nearest(category)),
        ],
      ],
    );
  }

  List<Widget> _list(
      BuildContext context, AppLocalizations l10n, List<PlaceHit> hits) {
    if (hits.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(l10n.simpleBikeNearbyNone,
              style: TextStyle(color: context.palette.textTertiary)),
        ),
      ];
    }
    const buttonSize = Size(48, 48);
    return [
      for (final hit in hits)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: EditorialCard(
            key: Key('simpleBikePlace_${hit.place.id}'),
            radius: context.shape.radiusLg,
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hit.place.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (hit.distanceKm != null)
                  Text(
                    l10n.simpleBikeNearbyDistance(
                        hit.distanceKm!.toStringAsFixed(1)),
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary),
                  ),
                Wrap(
                  children: [
                    if (telUri(hit.place.phone) case final tel?)
                      TextButton.icon(
                        style: TextButton.styleFrom(minimumSize: buttonSize),
                        onPressed: () => PlaceLaunchActions.call(context, tel),
                        icon: const Icon(Icons.call_outlined),
                        label: Text(l10n.call),
                      ),
                    TextButton.icon(
                      style: TextButton.styleFrom(minimumSize: buttonSize),
                      onPressed: () => PlaceLaunchActions.openDirections(
                          context, ref, hit.place),
                      icon: const Icon(Icons.directions_outlined),
                      label: Text(l10n.directions),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  static String _errorText(Object error, AppLocalizations l10n) =>
      switch (error) {
        PlaceLocationException(problem: PlaceLocationProblem.serviceDisabled) =>
          l10n.errLocationOff,
        PlaceLocationException() => l10n.errLocationPermission,
        _ => mapFirestoreError(error, l10n),
      };
}
