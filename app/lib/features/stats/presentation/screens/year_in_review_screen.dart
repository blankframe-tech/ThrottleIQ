import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_check_gate.dart' show kPlayStoreUrl;
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_theme_style.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/year_in_review.dart';
import '../providers/rider_stats_provider.dart';

/// A shareable image of one year's riding, built from local stats.
class YearInReviewScreen extends ConsumerStatefulWidget {
  const YearInReviewScreen({super.key, this.initialYear});

  /// Year to open on, if the rider has rides in it; else the newest.
  final int? initialYear;

  @override
  ConsumerState<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _YearInReviewScreenState extends ConsumerState<YearInReviewScreen> {
  final GlobalKey _cardKey = GlobalKey();
  // Anchors the iOS/iPad share popover — see active_ride_screen.dart.
  final GlobalKey _shareButtonKey = GlobalKey();
  late int? _year = widget.initialYear;
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
    final statsAsync = ref.watch(riderStatsProvider);
    final stats = statsAsync.valueOrNull;
    // An older cached summary has no allRides; same fallback as BadgeStats.
    final rides = stats == null
        ? const <RideEntity>[]
        : (stats.allRides.isNotEmpty ? stats.allRides : stats.recentRides);
    final bikes = ref.watch(allBikesProvider).valueOrNull ?? [];
    final years = rideYears(rides);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(l10n.yearInReviewTitle)),
      body: stats == null && statsAsync.hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.yearInReviewLoadFailed),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(riderStatsProvider),
                    child: Text(l10n.tryAgain),
                  ),
                ],
              ),
            )
          : stats == null
              ? const Center(child: CircularProgressIndicator())
              : years.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.noRidesYetDot),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.go('/home/record'),
                            child: Text(l10n.startRide),
                          ),
                        ],
                      ),
                    )
                  : Builder(builder: (context) {
                      final year = years.contains(_year) ? _year! : years.first;
                      final review = computeYearInReview(rides, year);
                      // A deleted bike has no name; leave the row off a public image.
                      final bikeName = bikes
                          .where((b) => b.id == review.favouriteBikeId)
                          .map((b) => b.displayName)
                          .firstOrNull;
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (years.length > 1)
                            SingleChildScrollView(
                              key: const Key('year_in_review_year'),
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final y in years) ...[
                                    ChoiceChip(
                                      key: Key('year_in_review_year_$y'),
                                      label: Text('$y'),
                                      selected: y == year,
                                      onSelected: (_) =>
                                          setState(() => _year = y),
                                      selectedColor: context.palette.primary
                                          .withValues(alpha: 0.18),
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: y == year
                                            ? context.palette.primary
                                            : context.palette.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          Center(
                            // Preview scaled to fit; the boundary is always
                            // 360×640, so the PNG is 1080×1920 (9:16).
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.sizeOf(context).height * 0.62),
                              child: AspectRatio(
                                aspectRatio: _YearCard.size.aspectRatio,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      context.shape.radiusXl),
                                  child: FittedBox(
                                    child: RepaintBoundary(
                                      key: _cardKey,
                                      child: _YearCard(
                                          review: review, bikeName: bikeName),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: _shareButtonKey,
                            onPressed: _sharing ? null : () => _share(year),
                            icon: _sharing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.ios_share),
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
  final String? bikeName;

  const _YearCard({required this.review, this.bikeName});

  /// Logical size of the exported image; ×3 pixel ratio gives 1080×1920.
  static const size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // One format for every distance: grouped, at most one decimal. Digits
    // stay Western in Bangla too, per core/i18n/numeric_locale.dart.
    final km = NumberFormat('#,##0.#', kNumericLocale);
    final change = review.changeVsPrevious;
    final busiest = review.busiestMonth;
    // The current year isn't over: say so, or a shared total reads as final.
    final soFar = review.inProgress;
    // Fixed colours, not the sharer's theme: every exported image looks the
    // same whether the rider uses the light or the dark skin.
    const p = AppColorPalette.carbonMonoDark;
    final labelStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold, color: p.onInkMuted);
    // MergeSemantics: a screen reader hears "Total rides, 42", not two items.
    Widget stat(String label, String value) => MergeSemantics(
            child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(context, 20, color: p.onInk)),
            ],
          ),
        ));
    // Supporting figures sit two to a row under the hero distance.
    final tiles = [
      stat(l10n.totalRides, '${review.rideCount}'),
      stat(l10n.yearInReviewRideTime,
          l10n.yearInReviewHours(km.format(review.rideSeconds / 3600))),
      stat(l10n.yearInReviewLongestRide,
          '${km.format(review.longestRideKm)} ${l10n.distanceStatLabel}'),
      if (busiest != null)
        stat(
            l10n.yearInReviewBusiestMonth,
            // Month names follow the UI language; only digits are pinned Western.
            DateFormat.MMMM(Localizations.localeOf(context).toLanguageTag())
                .format(DateTime(review.year, busiest))),
      if (bikeName != null) stat(l10n.yearInReviewFavouriteBike, bikeName!),
    ];

    // A fixed 360x640 canvas: the system text size would overflow it, and
    // the preview scales as a whole anyway.
    return MediaQuery.withNoTextScaling(
        child: Container(
      key: const Key('year_in_review_card'),
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(20),
      // Its own look, not a settings card: an ink panel warming into the
      // brand colour, light display type on top.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.ink, Color.lerp(p.ink, p.primary, 0.3)!],
        ),
        // Square: rounded corners export as transparent pixels that chat
        // apps fill with black or white. The preview is rounded outside.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/app_icon.png',
                    width: 28, height: 28),
              ),
              const SizedBox(width: 8),
              Text('ThrottleIQ', style: display(context, 18, color: p.onInk)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
              soFar
                  ? l10n.yearInReviewHeadingSoFar('${review.year}')
                  : l10n.yearInReviewHeading('${review.year}'),
              style: display(context, 22, color: p.onInk)),
          const SizedBox(height: 12),
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.totalDistance, style: labelStyle),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: km.format(review.distanceKm),
                        style: display(context, 56,
                            height: 1.05, color: p.primary)),
                    TextSpan(
                        text: ' ${l10n.distanceStatLabel}',
                        style: display(context, 24, color: p.onInk)),
                  ])),
                ),
                if (change != null)
                  Text(
                      (soFar
                              ? l10n.yearInReviewVsYearSoFar
                              : l10n.yearInReviewVsYear)(
                          '${change >= 0 ? '+' : '−'}${(change.abs() * 100).round()}%',
                          '${review.year - 1}'),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: change >= 0 ? p.primary : p.onInkMuted)),
              ],
            ),
          ),
          for (var t = 0; t < tiles.length; t += 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tiles[t]),
                const SizedBox(width: 12),
                Expanded(
                    child: t + 1 < tiles.length
                        ? tiles[t + 1]
                        : const SizedBox.shrink()),
              ],
            ),
          const Spacer(),
          _MonthBars(review.monthKm,
              highlight: busiest,
              color: p.primary,
              muted: p.onInk.withValues(alpha: 0.18)),
          const SizedBox(height: 16),
          // The image travels without the app; this is the way back to it.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                color: p.onInk,
                child: QrImageView(
                  data: kPlayStoreUrl,
                  size: 56,
                  padding: EdgeInsets.zero,
                  backgroundColor: p.onInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.yearInReviewGetApp,
                    style: TextStyle(fontSize: 12, color: p.onInkMuted)),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}

/// Twelve bars, January to December, scaled to the biggest month. Decorative:
/// the busiest month is also stated in words, so screen readers skip it.
class _MonthBars extends StatelessWidget {
  final List<double> monthKm;
  final int? highlight;
  final Color color;
  final Color muted;

  const _MonthBars(this.monthKm,
      {required this.highlight, required this.color, required this.muted});

  @override
  Widget build(BuildContext context) {
    final top = monthKm.fold<double>(0, (a, b) => b > a ? b : a);
    return ExcludeSemantics(
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var m = 0; m < 12; m++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FractionallySizedBox(
                    // A month with no riding still shows a sliver.
                    heightFactor:
                        top == 0 ? 0.06 : 0.06 + 0.94 * monthKm[m] / top,
                    alignment: Alignment.bottomCenter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: m + 1 == highlight ? color : muted,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
