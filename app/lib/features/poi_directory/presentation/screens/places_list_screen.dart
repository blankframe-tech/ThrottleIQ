import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../routes/presentation/screens/routes_list_screen.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/places_query.dart';
import '../place_category_l10n.dart';
import '../place_category_style.dart';
import '../place_tag_l10n.dart';
import '../providers/places_provider.dart';
import '../providers/places_search_provider.dart';
import '../widgets/highway_radar_banner.dart';
import '../widgets/place_card.dart';
import '../widgets/places_filter_sheet.dart';
import '../widgets/places_map_view.dart';
import '../widgets/places_status_views.dart';
import '../widgets/saved_places_tab.dart';

/// The hub's three top-level views.
enum PlacesHubTab { places, routes, saved }

/// Places bottom-nav tab — the rider's waypoint & exploration hub.
///
/// * **Places**: search, a horizontal category ribbon with counts, the
///   Highway Radar alert, and a map (default) or list of nearby stops, each
///   with one-tap Directions / Call / Save.
/// * **Routes**: the saved/discoverable routes browser, which used to hang
///   off a lone "Browse routes" button between the chips and the list.
/// * **Saved**: local bookmarks (work offline) and the places the rider added.
///
/// Speed cameras and police checkposts are no longer categories here; they
/// live in the Highway Radar. The OpenStreetMap import moved from an
/// unexplained AppBar icon to an explained empty-state action and the
/// overflow menu.
class PlacesListScreen extends ConsumerStatefulWidget {
  const PlacesListScreen({super.key});

  @override
  ConsumerState<PlacesListScreen> createState() => _PlacesListScreenState();
}

class _PlacesListScreenState extends ConsumerState<PlacesListScreen> {
  PlacesHubTab _tab = PlacesHubTab.places;
  final Set<PlacesHubTab> _visited = {PlacesHubTab.places};
  final _searchCtrl = TextEditingController();
  bool _importing = false;

  void _selectTab(PlacesHubTab tab) => setState(() {
        _tab = tab;
        _visited.add(tab);
      });

  @override
  void initState() {
    super.initState();
    // The notifier outlives this screen (it isn't autoDispose), so a search
    // typed before switching bottom-nav tabs is still applied — show it.
    _searchCtrl.text = ref.read(placesQueryProvider).text;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _importNearby({bool confirm = true}) async {
    if (_importing) return;
    final radius = ref.read(placesQueryProvider).radiusKm;
    if (confirm) {
      final km = formatRadiusKm(radius > osmImportMaxRadiusKm ? osmImportMaxRadiusKm : radius);
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.placesOsmDialogTitle),
          content: Text(dialogContext.l10n.placesOsmDialogBody(km)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.cancelAction),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.placesOsmImportAction),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    setState(() => _importing = true);
    try {
      final count = await importNearbyOsmPlaces(ref, radiusKm: radius);
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
  Future<void> _addPlace() async {
    final added = await context.push<bool>('/home/places/add');
    if (added == true) {
      ref.invalidate(nearbyPlacesProvider);
      ref.invalidate(myPlacesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(placesViewModeProvider);
    final mapMode = _tab == PlacesHubTab.places && viewMode == PlacesViewMode.map;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(context.l10n.navPlacesLabel),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.l10n.placesMoreActions,
            onSelected: (value) {
              switch (value) {
                case 'osm':
                  _importNearby();
                case 'mine':
                  context.push('/places/mine');
              }
            },
            itemBuilder: (menuContext) => [
              PopupMenuItem(
                value: 'osm',
                enabled: !_importing,
                // §97.1: Replaced ListTile with Row inside PopupMenuItem to avoid layout and accessibility issues
                // that can occur when nesting a complex widget like ListTile inside a popup menu context.
                child: Row(
                  children: [
                    const Icon(Icons.travel_explore_outlined),
                    const SizedBox(width: 12),
                    Text(menuContext.l10n.importNearbyPlacesFrom),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mine',
                // §97.1: Replaced ListTile with Row inside PopupMenuItem for the same layout/accessibility reasons.
                child: Row(
                  children: [
                    const Icon(Icons.add_location_alt_outlined),
                    const SizedBox(width: 12),
                    Text(menuContext.l10n.placesAddedByMe),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // The map has its own add button stacked with locate-me, clear of the
      // carousel; the Routes tab has nothing to add.
      floatingActionButton: _tab == PlacesHubTab.routes || mapMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add_place_fab',
              onPressed: _addPlace,
              backgroundColor: context.palette.primary,
              foregroundColor:
                  AppTheme.primaryButtonForeground(context.palette),
              icon: Icon(Icons.add,
                  color: AppTheme.primaryButtonForeground(context.palette)),
              label: Text(context.l10n.addPlaceLower,
                  style: TextStyle(
                      color:
                          AppTheme.primaryButtonForeground(context.palette))),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingMd,
              AppDimensions.paddingSm,
              AppDimensions.paddingMd,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<PlacesHubTab>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PlacesHubTab.places,
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: Text(context.l10n.placesHubTabPlaces),
                  ),
                  ButtonSegment(
                    value: PlacesHubTab.routes,
                    icon: const Icon(Icons.route, size: 18),
                    label: Text(context.l10n.placesHubTabRoutes),
                  ),
                  ButtonSegment(
                    value: PlacesHubTab.saved,
                    icon: const Icon(Icons.bookmark_outline, size: 18),
                    label: Text(context.l10n.placesHubTabSaved),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => _selectTab(s.first),
              ),
            ),
          ),
          Expanded(
            // IndexedStack, not a swipeable TabBarView: a horizontal swipe on
            // the map must pan the map, not flip to Routes. Each tab keeps
            // its state (scroll offset, the map camera) across switches.
            child: IndexedStack(
              index: _tab.index,
              children: [
                _PlacesExplorer(
                  searchController: _searchCtrl,
                  importing: _importing,
                  onImport: () => _importNearby(confirm: false),
                  onAddPlace: _addPlace,
                  onOpenSaved: () => _selectTab(PlacesHubTab.saved),
                ),
                // Built on first visit only: IndexedStack builds every child,
                // and the routes lists are two Firestore queries a rider who
                // never opens the tab shouldn't pay for.
                if (_visited.contains(PlacesHubTab.routes))
                  const RoutesBrowser()
                else
                  const SizedBox.shrink(),
                if (_visited.contains(PlacesHubTab.saved))
                  const SavedPlacesTab()
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Places tab: search, ribbon, radar, and the map or list.
class _PlacesExplorer extends ConsumerWidget {
  final TextEditingController searchController;
  final bool importing;
  final VoidCallback onImport;
  final VoidCallback onAddPlace;
  final VoidCallback onOpenSaved;

  const _PlacesExplorer({
    required this.searchController,
    required this.importing,
    required this.onImport,
    required this.onAddPlace,
    required this.onOpenSaved,
  });

  void _retry(WidgetRef ref) {
    ref.invalidate(currentPositionProvider);
    ref.invalidate(nearbyPlacesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(placesQueryProvider);
    final notifier = ref.read(placesQueryProvider.notifier);
    final batchAsync = ref.watch(placesBatchProvider);
    final position = ref.watch(currentPositionProvider).valueOrNull;
    final viewMode = ref.watch(placesViewModeProvider);
    final l10n = context.l10n;

    String categoryLabel(PlaceCategory c) => c.localizedName(l10n);

    final batch = batchAsync.valueOrNull ?? const <PlaceEntity>[];
    final counts = countByCategory(
      batch,
      query,
      originLat: position?.latitude,
      originLng: position?.longitude,
      categoryLabel: categoryLabel,
      tagLabel: (t) => t.localizedName(l10n),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMd,
            AppDimensions.paddingSm,
            AppDimensions.paddingSm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) => TextField(
                    controller: searchController,
                    onChanged: notifier.setTextDebounced,
                    onSubmitted: notifier.setText,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(color: context.palette.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.placesSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.placesClearSearch,
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                searchController.clear();
                                notifier.setText('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.placesFiltersTooltip,
                onPressed: () => PlacesFilterSheet.show(context),
                icon: Badge(
                  isLabelVisible: query.activeRefinementCount > 0,
                  label: Text('${query.activeRefinementCount}'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          // Ribbon height increased per §97.2 requirements.
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMd,
              vertical: 6,
            ),
            children: [
              _CategoryChip(
                key: const ValueKey('places-chip-all'),
                label: l10n.allFilter,
                icon: Icons.apps,
                accent: context.palette.primary,
                count: counts[null] ?? 0,
                selected: query.category == null,
                onTap: () => notifier.setCategory(null),
              ),
              for (final category in PlaceCategory.destinations)
                _CategoryChip(
                  key: ValueKey('places-chip-${category.name}'),
                  label: category.localizedName(l10n),
                  icon: category.markerIcon,
                  accent: category.accent(context),
                  count: counts[category] ?? 0,
                  selected: query.category == category,
                  onTap: () => notifier.setCategory(category),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(AppDimensions.paddingMd, 0, AppDimensions.paddingMd, 6),
          child: HighwayRadarBanner(),
        ),
        Expanded(
          child: batchAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: context.palette.primary)),
            error: (e, _) => PlacesErrorView(
              error: e,
              onRetry: () => _retry(ref),
              onOpenSaved: onOpenSaved,
            ),
            data: (places) {
              final hits = applyPlacesQuery(
                places,
                query,
                originLat: position?.latitude,
                originLng: position?.longitude,
                categoryLabel: categoryLabel,
                tagLabel: (t) => t.localizedName(l10n),
              );
              final radar = ref.watch(highwayRadarProvider);
              final nextRadius = placesRadiusOptionsKm
                  .where((km) => km > query.radiusKm)
                  .firstOrNull;

              Widget content;
              if (places.where((p) => !p.category.isSafetyPoint).isEmpty) {
                content = PlacesStatusPanel(
                  icon: Icons.travel_explore_outlined,
                  title: l10n.placesScanOsmTitle,
                  body: l10n.placesScanOsmBody,
                  actions: [
                    ElevatedButton.icon(
                      onPressed: importing ? null : onImport,
                      icon: importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore_outlined, size: 18),
                      label: Text(importing ? l10n.placesScanning : l10n.placesScanOsm),
                    ),
                    if (nextRadius != null)
                      OutlinedButton.icon(
                        onPressed: () => notifier.setRadius(nextRadius),
                        icon: const Icon(Icons.zoom_out_map, size: 18),
                        label: Text(l10n.placesWidenRadius(formatRadiusKm(nextRadius))),
                      ),
                    TextButton.icon(
                      onPressed: onAddPlace,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addPlaceLower),
                    ),
                  ],
                );
              } else if (hits.isEmpty) {
                content = PlacesStatusPanel(
                  icon: Icons.search_off,
                  title: l10n.placesNoMatches,
                  body: l10n.placesNoMatchesHint,
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () {
                        searchController.clear();
                        notifier
                          ..setText('')
                          ..setCategory(null)
                          ..clearRefinements();
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: Text(l10n.placesClearFilters),
                    ),
                    if (nextRadius != null)
                      TextButton.icon(
                        onPressed: () => notifier.setRadius(nextRadius),
                        icon: const Icon(Icons.zoom_out_map, size: 18),
                        label: Text(l10n.placesWidenRadius(formatRadiusKm(nextRadius))),
                      ),
                  ],
                );
              } else if (viewMode == PlacesViewMode.map) {
                content = PlacesMapView(
                  hits: hits,
                  radarPoints: radar.all,
                  origin: position == null ? null : LatLng(position.latitude, position.longitude),
                  radiusKm: query.radiusKm,
                  onAddPlace: onAddPlace,
                );
              } else {
                content = RefreshIndicator(
                  onRefresh: () {
                    ref.invalidate(currentPositionProvider);
                    return ref.refresh(nearbyPlacesProvider(query.radiusKm).future);
                  },
                  color: context.palette.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.paddingMd,
                      AppDimensions.paddingSm,
                      AppDimensions.paddingMd,
                      // Clear of the floating "Add place" button.
                      AppDimensions.paddingXl + 56,
                    ),
                    itemCount: hits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => PlaceCard(
                      key: ValueKey('place-card-${hits[i].place.id}'),
                      hit: hits[i],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.paddingMd,
                      0,
                      AppDimensions.paddingMd,
                      6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.placesResultCount(hits.length)} · '
                            '${l10n.radarWithin(formatRadiusKm(query.radiusKm))}',
                            style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                          ),
                        ),
                        SegmentedButton<PlacesViewMode>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          segments: [
                            ButtonSegment(
                              value: PlacesViewMode.map,
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: Text(l10n.placesMapView),
                            ),
                            ButtonSegment(
                              value: PlacesViewMode.list,
                              icon: const Icon(Icons.view_list_outlined, size: 16),
                              label: Text(l10n.placesListView),
                            ),
                          ],
                          selected: {viewMode},
                          onSelectionChanged: (s) =>
                              ref.read(placesViewModeProvider.notifier).state = s.first,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.shape.radiusFull),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.16) : context.palette.surface,
              borderRadius: BorderRadius.circular(context.shape.radiusFull),
              border: Border.all(color: selected ? accent : context.palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: selected ? accent : context.palette.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? context.palette.textPrimary : context.palette.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: (selected ? accent : context.palette.textTertiary).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(context.shape.radiusFull),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? accent : context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
