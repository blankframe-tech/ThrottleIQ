import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/year_in_review.dart';
import '../providers/rider_stats_provider.dart';

/// A shareable image of one year's riding, built from local stats.
class YearInReviewScreen extends ConsumerStatefulWidget {
  const YearInReviewScreen({super.key});

  @override
  ConsumerState<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _YearInReviewScreenState extends ConsumerState<YearInReviewScreen> {
  final GlobalKey _cardKey = GlobalKey();
  // Anchors the iOS/iPad share popover — see active_ride_screen.dart.
  final GlobalKey _shareButtonKey = GlobalKey();
  int? _year;
  bool _sharing = false;

  Future<void> _share(int year) async {
    if (_sharing) return;
    final l10n = context.l10n;
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('card not laid out');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('PNG encode failed');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/throttleiq_year_$year.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;

      Rect? origin;
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: l10n.yearInReviewHeading('$year'),
        sharePositionOrigin: origin,
      );
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'year in review share');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.yearInReviewShareFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rides = ref.watch(riderStatsProvider).valueOrNull?.allRides ?? [];
    final bikes = ref.watch(allBikesProvider).valueOrNull ?? [];
    final years = rideYears(rides);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(l10n.yearInReviewTitle)),
      body: years.isEmpty
          ? Center(child: Text(l10n.noRidesYetDot))
          : Builder(builder: (context) {
              final year = years.contains(_year) ? _year! : years.first;
              final review = computeYearInReview(rides, year);
              final bikeId = review.favouriteBikeId;
              final bikeName = bikeId == null
                  ? '-'
                  : bikes
                          .where((b) => b.id == bikeId)
                          .map((b) => b.displayName)
                          .firstOrNull ??
                      l10n.analyticsUnknownBike;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (years.length > 1)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DropdownButton<int>(
                        key: const Key('year_in_review_year'),
                        value: year,
                        items: [
                          for (final y in years)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (y) => setState(() => _year = y),
                      ),
                    ),
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    key: _cardKey,
                    child: _YearCard(
                      review: review,
                      bikeName: bikeName,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: _shareButtonKey,
                    onPressed: _sharing ? null : () => _share(year),
                    icon: const Icon(Icons.ios_share),
                    label: Text(l10n.shareAction),
                  ),
                ],
              );
            }),
    );
  }
}

class _YearCard extends StatelessWidget {
  final YearInReview review;
  final String bikeName;

  const _YearCard({required this.review, required this.bikeName});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget stat(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: context.palette.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: display(context, 22)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusXl),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ThrottleIQ',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: context.palette.primary)),
          const SizedBox(height: 6),
          Text(l10n.yearInReviewHeading('${review.year}'),
              style: display(context, 28)),
          stat(
              l10n.totalDistance, '${review.distanceKm.toStringAsFixed(0)} km'),
          stat(l10n.totalRides, '${review.rideCount}'),
          stat(l10n.yearInReviewLongestRide,
              '${review.longestRideKm.toStringAsFixed(1)} km'),
          stat(l10n.yearInReviewFavouriteBike, bikeName),
        ],
      ),
    );
  }
}
