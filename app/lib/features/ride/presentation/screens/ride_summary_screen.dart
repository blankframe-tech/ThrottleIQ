import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/cloud/export_service.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/downsample.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../core/utils/riding_score.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/full_screen_route_map_screen.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../shared/widgets/riding_score_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stats/presentation/widgets/ride_line_chart.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/calculators/elevation_profile.dart';
import '../../domain/calculators/speed_segments.dart';
import '../../domain/calculators/segment_speed_aggregator.dart';
import '../../domain/calculators/speed_baseline.dart';
import '../widgets/bike_confirmation_card.dart';
import '../widgets/change_bike_control.dart';
import '../providers/ride_recording_provider.dart';
import '../../../../core/cloud/ride_track_loader.dart';
import '../../../../core/cloud/cloud_repository.dart';
import '../../../../core/services/weather_service.dart';
import '../../../../shared/widgets/app_tile_layer.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

enum _ExportFormat { json, gpx, csv }

class RideSummaryScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideSummaryScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends ConsumerState<RideSummaryScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _polyline = [];
  List<double> _speedsMs = [];
  List<double?> _altitudesM = [];
  bool _polylineLoaded = false;
  ({double riderKmh, double baselineKmh})? _speedOutlier;
  RideWeather? _weather;
  bool _weatherChecked = false;
  // Anchors the iOS share popover to the tapped button (issues §48) —
  // without a non-zero sharePositionOrigin, UIActivityViewController throws
  // instead of presenting, same root cause active_ride_screen.dart's
  // _shareButtonKey was added for.
  final GlobalKey _exportJsonButtonKey = GlobalKey();
  final GlobalKey _exportGpxButtonKey = GlobalKey();
  final GlobalKey _exportCsvButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadPolyline();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Local trail, else the cloud copy (a ride restored onto a new phone has
  // no local points) — see RideTrackLoader. The `mounted` check matters now
  // that a network round trip sits before setState.
  Future<void> _loadPolyline() async {
    final points = await RideTrackLoader.load(widget.rideId);
    if (!mounted) return;
    setState(() {
      _polyline = points
          .map((p) => LatLng(
              (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
          .toList();
      _speedsMs = points.map((p) => (p['speed_ms'] as num).toDouble()).toList();
      _altitudesM =
          points.map((p) => (p['altitude_m'] as num?)?.toDouble()).toList();
      _polylineLoaded = true;
    });
    unawaited(_checkSpeedOutlier());
  }

  /// Compares this ride's fastest road-segment (a geohash cell, see
  /// `segment_speed_aggregator.dart`) against the anonymous historical
  /// baseline pooled for that same segment, and — only if there's enough
  /// pooled history to mean anything and this ride was a real statistical
  /// outlier there (`speed_baseline.dart`) — surfaces a private insight
  /// card. Shown only to this rider, about their own ride; never posted,
  /// shared, or visible to anyone else. Best-effort: any failure (offline,
  /// no pooled data yet — the common case for a while at beta scale) just
  /// means no card, never an error the rider sees.
  Future<void> _checkSpeedOutlier() async {
    if (_polyline.length < 2 || _speedsMs.length != _polyline.length) return;

    final segments = averageSpeedPerSegment([
      for (var i = 0; i < _polyline.length; i++)
        (lat: _polyline[i].latitude, lng: _polyline[i].longitude, speedMs: _speedsMs[i]),
    ]);
    if (segments.isEmpty) return;
    final fastest = segments.reduce((a, b) => a.avgSpeedKmh >= b.avgSpeedKmh ? a : b);

    try {
      final historical =
          await CloudRepository().fetchRoadSpeedSamples(fastest.segmentId);
      final baseline = computeBaseline(historical);
      if (baseline == null || !isSpeedOutlier(fastest.avgSpeedKmh, baseline)) return;
      if (!mounted) return;
      setState(() {
        _speedOutlier = (riderKmh: fastest.avgSpeedKmh, baselineKmh: baseline.meanKmh);
      });
    } catch (e) {
      debugPrint('[RideSummary] speed-outlier check failed: $e');
    }
  }

  Future<void> _fetchWeather(RideEntity ride) async {
    if (_weatherChecked || _polyline.isEmpty) return;
    _weatherChecked = true;
    try {
      final w = await WeatherService().fetchForRide(
        lat: _polyline.first.latitude,
        lng: _polyline.first.longitude,
        at: ride.startTime,
      );
      if (mounted) {
        setState(() => _weather = w);
      }
    } catch (e) {
      debugPrint('[RideSummary] weather fetch failed: $e');
    }
  }

  Widget _buildWeatherChip(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_weatherChecked && _weather == null) {
      return const SizedBox.shrink();
    }
    if (_weather != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.palette.onInk.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_outlined, size: 13, color: context.palette.onInk),
            const SizedBox(width: 4),
            Text(
              '${_weather!.tempC.round()}°C',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.palette.onInk,
              ),
            ),
          ],
        ),
      );
    }
    return Tooltip(
      message: l10n.weatherUnavailableTooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.palette.onInk.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.onInkMuted.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 13, color: context.palette.onInkMuted),
            const SizedBox(width: 4),
            Text(
              '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.palette.onInkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(rideDetailProvider(widget.rideId));
    final rideVal = rideAsync.valueOrNull;
    if (rideVal != null && !_weatherChecked && _polyline.isNotEmpty) {
      unawaited(_fetchWeather(rideVal));
    }
    final name = ref.watch(currentUserProvider)?.displayName?.split(' ').first;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        leading: IconButton(
          tooltip: context.l10n.close,
          icon: const Icon(Icons.close),
          onPressed: () => _dismiss(context),
        ),
      ),
      body: rideAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(rideDetailProvider(widget.rideId)),
        ),
        data: (ride) {
          if (ride == null) {
            return Center(
                child: Text(l10n.rideNotFoundMessage,
                    style: TextStyle(color: context.palette.textSecondary)));
          }

          final startCenter = _polyline.isNotEmpty
              ? _polyline.first
              : const LatLng(23.8103, 90.4125);
          final score = computeRidingScore(
            hardBrakes: ride.hardBrakeCount,
            rapidAccel: ride.rapidAccelCount,
            highJerk: ride.highJerkCount,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 0,
                AppDimensions.paddingMd, AppDimensions.paddingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Only renders for an auto-detected ride whose bike the
                // app guessed and the rider hasn't confirmed — see
                // BikeConfirmationCard. No-op on every other ride.
                BikeConfirmationCard(ride: ride),

                // Lets the rider fix a wrong bike pick, but only on the ride
                // they just finished — see ChangeBikeControl. No-op on
                // every older ride, and a no-op when BikeConfirmationCard
                // above is already showing for this same ride.
                ChangeBikeControl(ride: ride),

                // ── Black "nice ride" header ─────────────────────────────
                InkPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          name != null
                              ? l10n.niceRideGreetingNamed(name)
                              : l10n.niceRideGreeting,
                          style: display(context, 24, color: context.palette.onInk)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDate(ride.startTime),
                              style: TextStyle(
                                  fontSize: 13, color: context.palette.onInkMuted)),
                          _buildWeatherChip(context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Core stats, icon+color coded — same treatment as the
                // social shared-ride-detail screen's metric tiles.
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: l10n.maxSpeedStatLabel,
                        value: ride.maxSpeedKmh.toStringAsFixed(0),
                        unit: 'km/h',
                        icon: Icons.speed,
                        accentColor: context.palette.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        title: l10n.avgSpeedStatLabel,
                        value: ride.avgSpeedKmh.toStringAsFixed(0),
                        unit: 'km/h',
                        icon: Icons.trending_up,
                        accentColor: context.palette.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: l10n.distanceStatLabel,
                        value: ride.distanceKm.toStringAsFixed(1),
                        unit: 'km',
                        icon: Icons.straighten,
                        accentColor: context.palette.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        title: l10n.durationStatLabel,
                        value: SpeedFormatter.durationFromSeconds(
                            ride.durationSeconds ?? 0),
                        unit: '',
                        icon: Icons.timer_outlined,
                        accentColor: context.palette.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Jam time ─────────────────────────────────────────────
                // Only rendered when moving time survived to this ride's row
                // (see jam_time.dart / RideEntity.jamSeconds) — older rides
                // finalized before it was tracked have nothing honest to show
                // here, so the card is skipped rather than showing a 0 that
                // looks like "no jam" when it really means "unknown".
                if (ride.jamSeconds != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: l10n.movingStatLabel,
                          value: SpeedFormatter.durationFromSeconds(
                              ride.movingSeconds ?? 0),
                          unit: '',
                          icon: Icons.directions,
                          accentColor: context.palette.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          title: l10n.jamStatLabel,
                          value: SpeedFormatter.durationFromSeconds(
                              ride.jamSeconds!),
                          unit: '',
                          icon: Icons.traffic,
                          accentColor: ride.jamSeconds! > 0
                              ? context.palette.attention
                              : context.palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Riding score, gamified badge (matches the social
                // shared-ride-detail screen instead of a flat number tile).
                RidingScoreBadge(score: score),
                const SizedBox(height: 12),

                // ── Events ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: l10n.hardBrakesStatLabel,
                        value: '${ride.hardBrakeCount}',
                        unit: '',
                        icon: Icons.warning_amber_rounded,
                        accentColor: ride.hardBrakeCount > 0
                            ? context.palette.danger
                            : context.palette.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricCard(
                        title: l10n.rapidAccelStatLabel,
                        value: '${ride.rapidAccelCount}',
                        unit: '',
                        icon: Icons.bolt,
                        accentColor: ride.rapidAccelCount > 0
                            ? context.palette.attention
                            : context.palette.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricCard(
                        title: l10n.highJerkStatLabel,
                        value: '${ride.highJerkCount}',
                        unit: '',
                        icon: Icons.vibration,
                        accentColor: ride.highJerkCount > 0
                            ? context.palette.attention
                            : context.palette.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Riding pace ──────────────────────────────────────────
                _buildPaceCard(l10n, ride),
                const SizedBox(height: 16),

                // ── Map ──────────────────────────────────────────────────
                EditorialLabel(l10n.routeSectionLabel),
                const SizedBox(height: 10),
                _buildMap(ride, startCenter, l10n),
                _buildSpeedLegend(l10n),
                _buildSpeedOutlierCard(l10n),
                const SizedBox(height: 16),
                _buildRouteInfoCard(l10n, ride),
                const SizedBox(height: 16),

                // ── Telemetry profiles ───────────────────────────────────
                // Both charted from data the recorder already captured but
                // never surfaced anywhere before: per-point speed always,
                // per-point altitude only when the device actually had a
                // usable barometer/GPS-altitude fix for this ride.
                _buildSpeedProfileSection(l10n),
                _buildElevationSection(l10n),

                // ── Actions ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _dismiss(context),
                        child: Text(l10n.saveAndDoneAction),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !_polylineLoaded
                            ? null
                            : () => context.push('/ride/share/${ride.id}'),
                        icon: const Icon(Icons.public, size: 18),
                        label: Text(l10n.shareAction),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Telemetry export ─────────────────────────────────────
                EditorialLabel(l10n.telemetrySectionLabel),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      key: _exportJsonButtonKey,
                      onPressed: () => _exportRide(ride,
                          format: _ExportFormat.json,
                          buttonKey: _exportJsonButtonKey),
                      icon: const Icon(Icons.data_object, size: 18),
                      label: Text(l10n.exportJsonAction),
                    ),
                    TextButton.icon(
                      key: _exportGpxButtonKey,
                      onPressed: () => _exportRide(ride,
                          format: _ExportFormat.gpx,
                          buttonKey: _exportGpxButtonKey),
                      icon: const Icon(Icons.route, size: 18),
                      label: Text(l10n.exportGpxAction),
                    ),
                    TextButton.icon(
                      key: _exportCsvButtonKey,
                      onPressed: () => _exportRide(ride,
                          format: _ExportFormat.csv,
                          buttonKey: _exportCsvButtonKey),
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: Text(l10n.exportCsvAction),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Reached two ways: pushed on top of a rides list (bike detail / all
  // rides / stats) to view a past ride, or `go`'d straight here from
  // active_ride_screen right after finishing a recording, which replaces
  // the stack so there's nothing to pop back to. `canPop` tells them apart —
  // pop back to the list in the first case, fall back to the record screen
  // only when there truly is no prior screen.
  void _dismiss(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home/record');
    }
  }

  /// Average *moving* speed, replacing a runner's min/km pace that meant
  /// nothing to a motorcyclist (grill §3.3.4). Falls back to elapsed
  /// time for older rides with no moving time recorded.
  Widget _buildPaceCard(AppLocalizations l10n, RideEntity ride) {
    final moving = ride.movingSeconds;
    final seconds = (moving != null && moving > 0) ? moving : (ride.durationSeconds ?? 0);
    final avgKmh = (ride.distanceKm > 0 && seconds > 0)
        ? (ride.distanceKm / (seconds / 3600)).toStringAsFixed(0)
        : '--';
    final stopped = ride.jamSeconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.two_wheeler, size: 20, color: context.palette.primary),
              const SizedBox(width: 12),
              Text(l10n.ridingPaceLabel,
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
              const Spacer(),
              Text('$avgKmh km/h',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.palette.textPrimary,
                      fontSize: 14)),
            ],
          ),
          if (moving != null && stopped != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 32),
                Text(l10n.movingStoppedLabel,
                    style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
                const Spacer(),
                Text(
                    '${SpeedFormatter.durationFromSeconds(moving)} / '
                    '${SpeedFormatter.durationFromSeconds(stopped)}',
                    style: TextStyle(color: context.palette.textPrimary, fontSize: 14)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(1.0, 18.0));
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(1.0, 18.0));
    } catch (_) {}
  }

  void _recenterMap() {
    if (_polyline.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _polyline,
        padding: const EdgeInsets.all(32),
        maxZoom: 16,
      ),
    );
  }

  void _openFullScreenMap(RideEntity ride) {
    if (_polyline.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenRouteMapScreen(
          polyline: _polyline,
          title: _formatDate(ride.startTime),
          subtitle: '${ride.distanceKm.toStringAsFixed(1)} km · '
              '${SpeedFormatter.durationFromSeconds(ride.durationSeconds ?? 0)}',
          distanceKm: ride.distanceKm,
          durationSeconds: ride.durationSeconds ?? 0,
          maxSpeedKmh: ride.maxSpeedKmh,
          avgSpeedKmh: ride.avgSpeedKmh,
          // The richer save-route form (name, description, public toggle)
          // rather than the social screen's quick auto-named save — this is
          // the rider's own ride, so they get the full "My Routes" flow that
          // already exists at /routes/save/:rideId instead of a one-tap
          // stand-in for it.
          onSaveRoute: (ctx) => ctx.push('/routes/save/${ride.id}'),
        ),
      ),
    );
  }

  Widget _buildMap(RideEntity ride, LatLng startCenter, AppLocalizations l10n) {
    if (ride.mapSnapshotPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(context.shape.radiusXl),
        child: Image.file(File(ride.mapSnapshotPath!),
            height: 200, width: double.infinity, fit: BoxFit.cover),
      );
    }
    if (!_polylineLoaded) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusXl),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: context.palette.primary),
            const SizedBox(height: 12),
            Text(context.l10n.fetchingRoute,
                style: TextStyle(color: context.palette.textSecondary)),
          ],
        ),
      );
    }
    if (_polyline.isEmpty) {
      // Neither this phone nor the cloud has a trail (a ride recorded with no
      // GPS fix, or one whose trail never uploaded) — say so instead of
      // drawing an empty map centred on nothing.
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusXl),
          border: Border.all(color: context.palette.border),
        ),
        child: Center(
          child: Text(context.l10n.routeNotAvailable,
              style: TextStyle(color: context.palette.textSecondary)),
        ),
      );
    }
    // Falls back to a single primary-color line if speeds weren't captured
    // for this ride (e.g. an older row before speed_ms was populated) —
    // buildSpeedSegments returns [] in that case rather than misdrawing.
    final speedSegments = buildSpeedSegments(_polyline, _speedsMs);

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.shape.radiusXl),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: startCenter,
                initialCameraFit: _polyline.length > 1
                    ? CameraFit.coordinates(
                        coordinates: _polyline,
                        padding: const EdgeInsets.all(24),
                        maxZoom: 16,
                      )
                    : null,
                initialZoom: _polyline.length > 1 ? 13 : 15,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
                onTap: _polyline.isEmpty ? null : (_, __) => _openFullScreenMap(ride),
              ),
              children: [
                const AppTileLayer(),
                if (_polyline.length > 1)
                  PolylineLayer(
                    polylines: speedSegments.isNotEmpty
                        ? [
                            for (final segment in speedSegments)
                              Polyline(
                                points: segment.points,
                                color: _speedBandColor(segment.band),
                                strokeWidth: 4,
                              ),
                          ]
                        : [
                            Polyline(
                                points: _polyline,
                                color: context.palette.primary,
                                strokeWidth: 4),
                          ],
                  ),
                if (_polyline.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _polyline.first,
                        width: 16,
                        height: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.palette.success,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                      if (_polyline.length > 1)
                        Marker(
                          point: _polyline.last,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.palette.danger,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),

            if (_polyline.isNotEmpty)
              Positioned(
                left: 12,
                top: 12,
                child: GestureDetector(
                  onTap: () => _openFullScreenMap(ride),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.palette.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(context.shape.radiusFull),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_full, size: 14, color: context.palette.primary),
                        const SizedBox(width: 6),
                        Text(
                          l10n.mapExpandHintLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_polyline.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'ride_summary_zoom_in',
                      backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                      foregroundColor: context.palette.textPrimary,
                      tooltip: context.l10n.zoomIn,
                      onPressed: _zoomIn,
                      child: const Icon(Icons.add, size: 20),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'ride_summary_zoom_out',
                      backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                      foregroundColor: context.palette.textPrimary,
                      tooltip: context.l10n.zoomOut,
                      onPressed: _zoomOut,
                      child: const Icon(Icons.remove, size: 20),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'ride_summary_recenter',
                      backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                      foregroundColor: context.palette.textPrimary,
                      tooltip: context.l10n.recenterRoute,
                      onPressed: _recenterMap,
                      child: const Icon(Icons.my_location, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'ride_summary_fullscreen',
                      backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                      foregroundColor: context.palette.textPrimary,
                      tooltip: context.l10n.fullscreenMap,
                      onPressed: () => _openFullScreenMap(ride),
                      child: const Icon(Icons.fullscreen, size: 20),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'ride_summary_save_route',
                      backgroundColor: context.palette.primary,
                      foregroundColor: Colors.white,
                      tooltip: l10n.saveAsRouteAction,
                      onPressed: () => context.push('/routes/save/${ride.id}'),
                      child: const Icon(Icons.bookmark_add_outlined, size: 18),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _speedBandColor(SpeedBand band) {
    switch (band) {
      case SpeedBand.idle:
        return context.palette.textTertiary;
      case SpeedBand.normal:
        return context.palette.success;
      case SpeedBand.brisk:
        return context.palette.warning;
      case SpeedBand.hard:
        return context.palette.danger;
    }
  }

  String _speedBandLabel(AppLocalizations l10n, SpeedBand band) {
    switch (band) {
      case SpeedBand.idle:
        return l10n.speedBandIdleLabel;
      case SpeedBand.normal:
        return l10n.speedBandNormalLabel;
      case SpeedBand.brisk:
        return l10n.speedBandBriskLabel;
      case SpeedBand.hard:
        return l10n.speedBandHardLabel;
    }
  }

  Widget _buildSpeedLegend(AppLocalizations l10n) {
    if (_polyline.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final band in SpeedBand.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _speedBandColor(band),
                  ),
                ),
                const SizedBox(width: 4),
                Text(_speedBandLabel(l10n, band),
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedOutlierCard(AppLocalizations l10n) {
    final outlier = _speedOutlier;
    if (outlier == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.speed, color: context.palette.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.speedOutlierTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  l10n.speedOutlierBody(
                      outlier.riderKmh.round(), outlier.baselineKmh.round()),
                  style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard(AppLocalizations l10n, RideEntity ride) {
    if (_polyline.isEmpty) return const SizedBox.shrink();
    final start = _polyline.first;
    final end = _polyline.last;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 20, color: context.palette.primary),
              const SizedBox(width: 8),
              Text(
                l10n.routeGpsDetailsLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                l10n.trackPointsCountLabel(_polyline.length),
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: context.palette.success),
              ),
              const SizedBox(width: 8),
              Text('${l10n.startPointLabel}: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: context.palette.textPrimary)),
              Text(
                '${start.latitude.toStringAsFixed(4)}°, ${start.longitude.toStringAsFixed(4)}°',
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
            ],
          ),
          if (_polyline.length > 1) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.palette.danger),
                ),
                const SizedBox(width: 8),
                Text('${l10n.finishPointLabel}: ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: context.palette.textPrimary)),
                Text(
                  '${end.latitude.toStringAsFixed(4)}°, ${end.longitude.toStringAsFixed(4)}°',
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openFullScreenMap(ride),
              icon: const Icon(Icons.fullscreen, size: 18),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  l10n.exploreFullRouteAction,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A speed-over-route mini chart — every ride with a GPS track has this,
  /// unlike elevation below, since speed is always sampled (altitude
  /// depends on the device having a usable fix).
  Widget _buildSpeedProfileSection(AppLocalizations l10n) {
    if (_speedsMs.length < 2) return const SizedBox.shrink();
    final speedsKmh = [for (final s in _speedsMs) s * 3.6];
    final chartValues = downsample(speedsKmh, 60);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialLabel(l10n.speedProfileLabel),
          const SizedBox(height: 8),
          RideLineChart(
            values: chartValues,
            color: context.palette.primary,
            unit: 'km/h',
            xLabels: [l10n.startPointLabel, l10n.finishPointLabel],
          ),
        ],
      ),
    );
  }

  /// Elevation gain/loss + an altitude-over-route mini chart — only when
  /// `elevationGainLoss` finds enough honest signal to report (see that
  /// function's doc comment). Most rides on a phone with no barometer, or a
  /// GPS fix too coarse to resolve altitude, will have nothing here, and
  /// this section simply doesn't render rather than guessing.
  Widget _buildElevationSection(AppLocalizations l10n) {
    final elevation = elevationGainLoss(_altitudesM);
    if (elevation == null) return const SizedBox.shrink();

    final altitudes = _altitudesM.whereType<double>().toList();
    final chartValues = downsample(altitudes, 60);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: l10n.elevationGainLabel,
                  value: elevation.gainM.toStringAsFixed(0),
                  unit: 'm',
                  icon: Icons.trending_up,
                  accentColor: context.palette.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: l10n.elevationLossLabel,
                  value: elevation.lossM.toStringAsFixed(0),
                  unit: 'm',
                  icon: Icons.trending_down,
                  accentColor: context.palette.danger,
                ),
              ),
            ],
          ),
          if (chartValues.length >= 2) ...[
            const SizedBox(height: 12),
            EditorialLabel(l10n.elevationProfileLabel),
            const SizedBox(height: 8),
            RideLineChart(
              values: chartValues,
              color: context.palette.secondary,
              unit: 'm',
              xLabels: [l10n.startPointLabel, l10n.finishPointLabel],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportRide(
    RideEntity ride, {
    required _ExportFormat format,
    required GlobalKey buttonKey,
  }) async {
    final service = ExportService();
    final rideMap = {
      'id': ride.id,
      'startTime': ride.startTime.toIso8601String(),
      'endTime': ride.endTime?.toIso8601String(),
      'distanceM': ride.distanceM,
      'avgSpeedMs': ride.avgSpeedMs,
      'maxSpeedMs': ride.maxSpeedMs,
      'durationSeconds': ride.durationSeconds,
      'hardBrakeCount': ride.hardBrakeCount,
      'rapidAccelCount': ride.rapidAccelCount,
      'highJerkCount': ride.highJerkCount,
    };
    final file = await switch (format) {
      _ExportFormat.json => service.exportRideToJSON(rideMap),
      _ExportFormat.gpx => service.exportRideToGPX(rideMap),
      _ExportFormat.csv => service.exportRideToCSV(rideMap),
    };
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailedMessage)),
      );
      return;
    }
    Rect? origin;
    final box = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: l10n.rideExportShareSubject,
      sharePositionOrigin: origin,
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year} · '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
