import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/app_tile_layer.dart';
import '../../domain/marker_clustering.dart';
import '../../domain/places_query.dart';
import '../place_category_style.dart';
import '../providers/places_search_provider.dart';
import 'place_card.dart';

/// Same Dhaka fallback the add-place form and ride summary use — only ever
/// an initial camera when there's no fix and nothing to frame.
const _fallbackCenter = LatLng(23.8103, 90.4125);

/// Zoom that roughly frames a [radiusKm] circle on a phone.
double zoomForRadius(double radiusKm) {
  if (radiusKm <= 5) return 13;
  if (radiusKm <= 15) return 11.5;
  if (radiusKm <= 25) return 10.8;
  return 9.8;
}

/// Height of the bottom carousel strip.
const double placesCarouselHeight = 208;

/// The Places hub's map canvas: category-colored pins (grid-clustered when
/// they crowd), the search-radius ring, a pulsing "you are here" dot, the
/// Highway Radar's points in red when highlighted, and a snapping carousel
/// of place cards along the bottom kept in step with the pins — swipe a card
/// and the map pans to its pin; tap a pin and the carousel jumps to its card.
class PlacesMapView extends ConsumerStatefulWidget {
  final List<PlaceHit> hits;
  final List<PlaceHit> radarPoints;
  final LatLng? origin;
  final double radiusKm;

  /// "Add place", stacked with locate-me above the carousel — the screen's
  /// extended FAB would sit on top of the cards in map mode.
  final VoidCallback? onAddPlace;

  const PlacesMapView({
    super.key,
    required this.hits,
    required this.radarPoints,
    required this.origin,
    required this.radiusKm,
    this.onAddPlace,
  });

  @override
  ConsumerState<PlacesMapView> createState() => _PlacesMapViewState();
}

class _PlacesMapViewState extends ConsumerState<PlacesMapView>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  late final PageController _pageController = PageController(viewportFraction: 0.9);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  AnimationController? _cameraAnim;

  bool _mapReady = false;

  /// Floored zoom the current clusters were built for — clusters regroup
  /// only when this changes, not on every pan frame.
  late double _clusterZoom = zoomForRadius(widget.radiusKm).floorToDouble();

  /// Set while the carousel is being moved programmatically, so its own
  /// onPageChanged doesn't fight the marker tap that caused it.
  bool _jumpingCarousel = false;

  LatLng get _initialCenter => widget.origin ??
      (widget.hits.isNotEmpty
          ? LatLng(widget.hits.first.place.latitude, widget.hits.first.place.longitude)
          : _fallbackCenter);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A pulsing dot is decoration; honour "remove animations", and don't
    // leave an endless ticker running under widget tests' pumpAndSettle.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PlacesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radiusKm != widget.radiusKm && _mapReady) {
      _animateTo(widget.origin ?? _mapController.camera.center, zoomForRadius(widget.radiusKm));
    }
    if (oldWidget.hits != widget.hits && _pageController.hasClients) {
      final selected = ref.read(selectedPlaceIdProvider);
      final index = widget.hits.indexWhere((h) => h.place.id == selected);
      if (index < 0 && widget.hits.isNotEmpty && _pageController.page != 0) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _cameraAnim?.dispose();
    _pulse.dispose();
    _pageController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Smoothly flies the camera to [target]. flutter_map 7 has no animated
  /// move of its own, so this interpolates center and zoom over a short
  /// curve and moves the camera each tick.
  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady) return;
    final start = _mapController.camera;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _mapController.move(target, zoom);
      return;
    }
    _cameraAnim?.dispose();
    final anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _cameraAnim = anim;
    final curve = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
    final latTween = Tween(begin: start.center.latitude, end: target.latitude);
    final lngTween = Tween(begin: start.center.longitude, end: target.longitude);
    final zoomTween = Tween(begin: start.zoom, end: zoom);
    anim.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoomTween.evaluate(curve),
      );
    });
    anim.forward();
  }

  void _selectFromMarker(PlaceHit hit) {
    ref.read(selectedPlaceIdProvider.notifier).state = hit.place.id;
    final index = widget.hits.indexWhere((h) => h.place.id == hit.place.id);
    if (index >= 0 && _pageController.hasClients) {
      _jumpingCarousel = true;
      _pageController
          .animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
          .whenComplete(() => _jumpingCarousel = false);
    }
    _animateTo(
      LatLng(hit.place.latitude, hit.place.longitude),
      _mapController.camera.zoom < 14 ? 14 : _mapController.camera.zoom,
    );
  }

  void _onCarouselPage(int index) {
    if (_jumpingCarousel || index >= widget.hits.length) return;
    final hit = widget.hits[index];
    ref.read(selectedPlaceIdProvider.notifier).state = hit.place.id;
    _animateTo(LatLng(hit.place.latitude, hit.place.longitude), _mapController.camera.zoom);
  }

  void _zoomIntoCluster(MapCluster<PlaceHit> cluster) {
    _animateTo(
      LatLng(cluster.latitude, cluster.longitude),
      (_mapController.camera.zoom + 2).clamp(3, 18).toDouble(),
    );
  }

  void _locateMe() {
    final origin = widget.origin;
    if (origin == null) return;
    _animateTo(origin, zoomForRadius(widget.radiusKm) < 14 ? 14 : zoomForRadius(widget.radiusKm));
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedPlaceIdProvider);
    final highlightRadar = ref.watch(radarHighlightProvider);

    // When the radar list picked a point that isn't one of the hits, fly to
    // it; hits are handled by the carousel itself.
    ref.listen<String?>(selectedPlaceIdProvider, (_, id) {
      if (id == null) return;
      final radarHit = widget.radarPoints.where((h) => h.place.id == id).firstOrNull;
      if (radarHit != null) {
        _animateTo(LatLng(radarHit.place.latitude, radarHit.place.longitude), 15);
      }
    });

    final clusters = clusterByGrid<PlaceHit>(
      widget.hits,
      latitudeOf: (h) => h.place.latitude,
      longitudeOf: (h) => h.place.longitude,
      zoom: _clusterZoom,
    );

    final origin = widget.origin;
    final markers = <Marker>[
      for (final cluster in clusters)
        if (cluster.isSingle)
          Marker(
            key: ValueKey('place-marker-${cluster.items.first.place.id}'),
            point: LatLng(cluster.latitude, cluster.longitude),
            width: 44,
            height: 52,
            alignment: Alignment.topCenter,
            child: _PlacePin(
              hit: cluster.items.first,
              selected: cluster.items.first.place.id == selectedId,
              onTap: () => _selectFromMarker(cluster.items.first),
            ),
          )
        else
          Marker(
            point: LatLng(cluster.latitude, cluster.longitude),
            width: 48,
            height: 48,
            child: _ClusterBubble(
              count: cluster.items.length,
              onTap: () => _zoomIntoCluster(cluster),
            ),
          ),
      if (highlightRadar)
        for (final hit in widget.radarPoints)
          Marker(
            key: ValueKey('radar-marker-${hit.place.id}'),
            point: LatLng(hit.place.latitude, hit.place.longitude),
            width: 40,
            height: 40,
            child: _RadarPin(
              hit: hit,
              selected: hit.place.id == selectedId,
              pulse: _pulse,
            ),
          ),
      if (origin != null)
        Marker(
          point: origin,
          width: 44,
          height: 44,
          child: _UserDot(pulse: _pulse),
        ),
    ];

    final selectedHit = widget.hits.where((h) => h.place.id == selectedId).firstOrNull;
    final showCarousel = widget.hits.isNotEmpty;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: zoomForRadius(widget.radiusKm),
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () => _mapReady = true,
            onPositionChanged: (camera, _) {
              final z = camera.zoom.floorToDouble();
              if (z != _clusterZoom) setState(() => _clusterZoom = z);
            },
            onTap: (_, __) => ref.read(selectedPlaceIdProvider.notifier).state = null,
          ),
          children: [
            const AppTileLayer(),
            if (origin != null)
              CircleLayer(circles: [
                CircleMarker(
                  point: origin,
                  radius: widget.radiusKm * 1000,
                  useRadiusInMeter: true,
                  color: context.palette.primary.withValues(alpha: 0.05),
                  borderColor: context.palette.primary.withValues(alpha: 0.4),
                  borderStrokeWidth: 1.5,
                ),
              ]),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          right: 12,
          bottom: showCarousel ? placesCarouselHeight + 12 : 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onAddPlace != null) ...[
                FloatingActionButton.small(
                  heroTag: 'places_map_add',
                  tooltip: context.l10n.addPlaceLower,
                  backgroundColor: context.palette.primary,
                  foregroundColor: Colors.white,
                  onPressed: widget.onAddPlace,
                  child: const Icon(Icons.add_location_alt_outlined),
                ),
                const SizedBox(height: 10),
              ],
              FloatingActionButton.small(
                heroTag: 'places_locate_me',
                tooltip: context.l10n.placesLocateMe,
                backgroundColor: context.palette.surface,
                foregroundColor: context.palette.primary,
                onPressed: origin == null ? null : _locateMe,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        if (showCarousel)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            height: placesCarouselHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.hits.length,
              onPageChanged: _onCarouselPage,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: PlaceCard(
                    hit: widget.hits[i],
                    compact: true,
                    highlighted: widget.hits[i] == selectedHit,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlacePin extends StatelessWidget {
  final PlaceHit hit;
  final bool selected;
  final VoidCallback onTap;

  const _PlacePin({required this.hit, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = hit.place.category.accent(context);
    final size = selected ? 40.0 : 32.0;
    return Semantics(
      button: true,
      label: hit.place.name,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: selected ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: selected ? 0.55 : 0.3),
                    blurRadius: selected ? 12 : 6,
                    spreadRadius: selected ? 3 : 1,
                  ),
                ],
              ),
              child: Icon(hit.place.category.markerIcon, size: size * 0.5, color: Colors.white),
            ),
            if (hit.place.isRiderApproved)
              Icon(Icons.verified, size: 12, color: context.palette.success),
          ],
        ),
      ),
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ClusterBubble({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.placesResultCount(count),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.palette.primary.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: context.palette.primary.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 4),
            ],
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _RadarPin extends StatelessWidget {
  final PlaceHit hit;
  final bool selected;
  final Animation<double> pulse;

  const _RadarPin({required this.hit, required this.selected, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final danger = context.palette.danger;
    return Semantics(
      label: hit.place.name,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 24 + 16 * pulse.value,
              height: 24 + 16 * pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: danger.withValues(alpha: 0.35 * (1 - pulse.value)),
              ),
            ),
            child!,
          ],
        ),
        child: Container(
          width: selected ? 30 : 24,
          height: selected ? 30 : 24,
          decoration: BoxDecoration(
            color: danger,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(hit.place.category.markerIcon, size: 13, color: Colors.white),
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  final Animation<double> pulse;
  const _UserDot({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final color = context.palette.primary;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 16 + 28 * pulse.value,
              height: 16 + 28 * pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.3 * (1 - pulse.value)),
              ),
            ),
            child!,
          ],
        ),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}
