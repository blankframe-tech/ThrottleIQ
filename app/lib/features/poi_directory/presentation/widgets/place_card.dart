import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/place_directions.dart';
import '../../domain/places_query.dart';
import '../place_category_l10n.dart';
import '../place_category_style.dart';
import '../place_tag_l10n.dart';
import '../providers/saved_places_provider.dart';
import 'place_launch_actions.dart';
import 'place_rating_badges.dart';

/// The card action row's buttons: 40 dp tall (still a comfortable gloved
/// target) rather than the theme's full control height, so three fit on a
/// card in the fixed-height map carousel.
final ButtonStyle placeActionButtonStyle = TextButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 6),
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// A place in the hub's list, the map carousel and the Saved tab.
///
/// The three actions a rider at a red light actually wants — Directions,
/// Call, Save — sit on the card itself, one tap each, instead of behind the
/// detail screen. Tapping anywhere else opens the detail screen.
class PlaceCard extends ConsumerWidget {
  final PlaceHit hit;

  /// Carousel mode: no address or tag line, so the card fits the fixed-height
  /// strip over the map.
  final bool compact;

  /// Outline the card in the primary color (the carousel's selected place).
  final bool highlighted;

  const PlaceCard({
    super.key,
    required this.hit,
    this.compact = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = hit.place;
    final distanceKm = hit.distanceKm;
    final accent = place.category.accent(context);
    final tel = telUri(place.phone);

    final subtitle = [
      place.category.localizedName(context.l10n),
      if (distanceKm != null) ...[
        SpeedFormatter.distanceKm(distanceKm * 1000),
        context.l10n.placeApproxMinutes(approxRideMinutes(distanceKm)),
      ],
    ].join(' · ');

    final card = AppCard(
      onTap: () => context.push('/home/places/${place.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(place.category.markerIcon, size: 20, color: accent),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
              if (place.verified) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: context.l10n.placesVerifiedOnlyHint,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: context.palette.success),
                      const SizedBox(width: 2),
                      Text(
                        context.l10n.placeVerifiedBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.palette.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!compact && place.address.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              place.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
            ),
          ],
          const SizedBox(height: 8),
          PlaceRatingBadges(place: place, showEmpty: !compact, singleLine: compact),
          if (!compact && place.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                for (final tag in place.tags.take(3))
                  '${tag.icon} ${tag.localizedName(context.l10n)}',
              ].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Divider(height: 1, color: context.palette.border),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: placeActionButtonStyle,
                  onPressed: () => PlaceLaunchActions.openDirections(context, ref, place),
                  icon: const Icon(Icons.directions, size: 18),
                  label: Text(context.l10n.directions),
                ),
              ),
              if (tel != null)
                Expanded(
                  child: TextButton.icon(
                    style: placeActionButtonStyle,
                    onPressed: () => PlaceLaunchActions.call(context, tel),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(context.l10n.call),
                  ),
                ),
              Expanded(child: PlaceSaveButton(place: place)),
            ],
          ),
        ],
      ),
    );

    if (!highlighted) return card;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.shape.radiusXl + 2),
        border: Border.all(color: context.palette.primary, width: 2),
      ),
      child: card,
    );
  }
}

/// Bookmark toggle. [iconOnly] for app bars; otherwise an icon + label
/// button sized for a card's action row.
class PlaceSaveButton extends ConsumerWidget {
  final PlaceEntity place;
  final bool iconOnly;

  const PlaceSaveButton({super.key, required this.place, this.iconOnly = false});

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final saved = await ref.read(savedPlacesProvider.notifier).toggle(place);
      if (saved == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(saved ? l10n.placeSavedSnack : l10n.placeUnsavedSnack),
        ));
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'places: toggle saved place');
      messenger.showSnackBar(SnackBar(content: Text(l10n.placeSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPlaceIdsProvider.select((ids) => ids.contains(place.id)));
    final icon = Icon(saved ? Icons.bookmark : Icons.bookmark_border, size: 18);
    final label = saved ? context.l10n.placeSavedLabel : context.l10n.placeSave;
    if (iconOnly) {
      return IconButton(
        tooltip: label,
        onPressed: () => _toggle(context, ref),
        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
      );
    }
    return TextButton.icon(
      style: placeActionButtonStyle,
      onPressed: () => _toggle(context, ref),
      icon: icon,
      label: Text(label),
    );
  }
}
