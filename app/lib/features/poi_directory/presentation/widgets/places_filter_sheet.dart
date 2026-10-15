import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/place_tags.dart';
import '../../domain/places_query.dart';
import '../place_tag_l10n.dart';
import '../providers/places_search_provider.dart';

/// Formats a radius for display: `5`, `15`, `25`, `50` — no trailing `.0`.
String formatRadiusKm(double km) =>
    km == km.roundToDouble() ? km.toInt().toString() : km.toStringAsFixed(1);

/// The rider-centric refinements that don't deserve permanent screen space:
/// radius, sort, verified-only and features. Every control applies
/// immediately (the results update behind the sheet), so "Done" just closes.
class PlacesFilterSheet extends ConsumerWidget {
  const PlacesFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      builder: (_) => const PlacesFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(placesQueryProvider);
    final notifier = ref.read(placesQueryProvider.notifier);
    // Only the features that apply to the selected category; with "All",
    // every feature is fair game.
    final tags = query.category == null
        ? PlaceTag.values
        : PlaceTag.forCategory(query.category!);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.palette.textSecondary,
            ),
          ),
        );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.placesFiltersTooltip,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: query.activeRefinementCount == 0
                        ? null
                        : () {
                            notifier.clearRefinements();
                            notifier.setRadius(placesDefaultRadiusKm);
                          },
                    child: Text(context.l10n.placesFiltersReset),
                  ),
                ],
              ),
              heading(context.l10n.placesRadiusLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final km in placesRadiusOptionsKm)
                    ChoiceChip(
                      label: Text(context.l10n.placesRadiusKm(formatRadiusKm(km))),
                      selected: query.radiusKm == km,
                      onSelected: (_) => notifier.setRadius(km),
                    ),
                ],
              ),
              heading(context.l10n.placesSortLabel),
              SegmentedButton<PlacesSort>(
                segments: [
                  ButtonSegment(
                    value: PlacesSort.distance,
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: Text(context.l10n.placesSortDistance),
                  ),
                  ButtonSegment(
                    value: PlacesSort.rating,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: Text(context.l10n.placesSortRating),
                  ),
                ],
                selected: {query.sort},
                onSelectionChanged: (s) => notifier.setSort(s.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: query.verifiedOnly,
                onChanged: notifier.setVerifiedOnly,
                title: Text(context.l10n.placesVerifiedOnly,
                    style: TextStyle(color: context.palette.textPrimary)),
                subtitle: Text(context.l10n.placesVerifiedOnlyHint,
                    style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
              ),
              heading(context.l10n.placesFeaturesLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text('${tag.icon} ${tag.localizedName(context.l10n)}'),
                      selected: query.tags.contains(tag),
                      onSelected: (_) => notifier.toggleTag(tag),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
