import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../domain/highway_radar.dart';
import '../place_category_l10n.dart';
import '../place_category_style.dart';
import '../providers/places_search_provider.dart';
import 'place_launch_actions.dart';
import 'places_filter_sheet.dart';

/// "⚠ Highway Radar — 2 speed cameras · 1 police checkpost within 25 km".
///
/// Speed cameras and checkposts used to be two more category chips next to
/// "Recreation", as if a checkpost were somewhere to ride to. They're road
/// hazards, so they get their own alert: tapping it switches to the map and
/// paints them red there; the list icon shows them nearest-first; ✕ hides
/// the banner for the session.
class HighwayRadarBanner extends ConsumerWidget {
  const HighwayRadarBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radar = ref.watch(highwayRadarProvider);
    final dismissed = ref.watch(radarDismissedProvider);
    if (radar.isEmpty || dismissed) return const SizedBox.shrink();

    final highlighted = ref.watch(radarHighlightProvider);
    final radius = ref.watch(placesQueryProvider.select((q) => q.radiusKm));
    final danger = context.palette.danger;
    final nearest = radar.nearest;

    final summary = [
      if (radar.cameras.isNotEmpty) context.l10n.radarCameras(radar.cameras.length),
      if (radar.police.isNotEmpty) context.l10n.radarPolice(radar.police.length),
    ].join(' · ');

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: danger.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.shape.radiusLg),
          side: BorderSide(color: danger.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.shape.radiusLg),
          onTap: () {
            final next = !highlighted;
            ref.read(radarHighlightProvider.notifier).state = next;
            if (next) {
              ref.read(placesViewModeProvider.notifier).state = PlacesViewMode.map;
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: danger, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.l10n.radarTitle}: $summary',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        [
                          context.l10n.radarWithin(formatRadiusKm(radius)),
                          if (nearest?.distanceKm != null)
                            context.l10n.radarNearest(
                                SpeedFormatter.distanceKm(nearest!.distanceKm! * 1000)),
                          highlighted ? context.l10n.radarHideOnMap : context.l10n.radarShowOnMap,
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.radarListTitle,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showList(context, radar),
                  icon: Icon(Icons.format_list_bulleted, color: danger, size: 20),
                ),
                IconButton(
                  tooltip: context.l10n.radarDismiss,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(radarDismissedProvider.notifier).state = true;
                    ref.read(radarHighlightProvider.notifier).state = false;
                  },
                  icon: Icon(Icons.close, color: context.palette.textSecondary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showList(BuildContext context, HighwayRadar radar) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      builder: (sheetContext) => _RadarListSheet(radar: radar),
    );
  }
}

class _RadarListSheet extends ConsumerWidget {
  final HighwayRadar radar;
  const _RadarListSheet({required this.radar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = radar.all;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                context.l10n.radarListTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: points.length,
                itemBuilder: (_, i) {
                  final hit = points[i];
                  final place = hit.place;
                  return ListTile(
                    leading: Icon(place.category.markerIcon, color: place.category.accent(context)),
                    title: Text(place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.palette.textPrimary)),
                    subtitle: Text(
                      [
                        place.category.localizedName(context.l10n),
                        if (hit.distanceKm != null)
                          SpeedFormatter.distanceKm(hit.distanceKm! * 1000),
                      ].join(' · '),
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                    trailing: IconButton(
                      tooltip: context.l10n.directions,
                      icon: const Icon(Icons.directions),
                      onPressed: () => PlaceLaunchActions.openDirections(context, ref, place),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      ref.read(radarHighlightProvider.notifier).state = true;
                      ref.read(placesViewModeProvider.notifier).state = PlacesViewMode.map;
                      ref.read(selectedPlaceIdProvider.notifier).state = place.id;
                    },
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
