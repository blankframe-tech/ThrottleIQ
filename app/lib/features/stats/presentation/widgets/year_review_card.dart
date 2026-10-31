import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../core/services/app_check_gate.dart' show kPlayStoreUrl;
import '../../../../core/theme/app_theme_style.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/year_in_review.dart';

/// The one-page summary of a year: the story's last slide.
class YearCard extends StatelessWidget {
  final YearInReview review;
  final String? bikeName;

  const YearCard({super.key, required this.review, this.bikeName});

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
        fontSize: 12, fontWeight: FontWeight.bold, color: p.textSecondary);
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
          // A light tint only: at 0.3 the grey text fell to ~2:1 in the
          // bottom corner. textSecondary keeps >= 4.5:1 across it.
          colors: [p.ink, Color.lerp(p.ink, p.primary, 0.15)!],
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
                          color: change >= 0 ? p.primary : p.textSecondary)),
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
          MonthBars(review.monthKm,
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
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
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
class MonthBars extends StatelessWidget {
  final List<double> monthKm;
  final int? highlight;
  final Color color;
  final Color muted;
  final double height;

  /// 0-1: bars grow from the floor as it rises (1 = full height).
  final double grow;

  const MonthBars(this.monthKm,
      {super.key,
      required this.highlight,
      required this.color,
      required this.muted,
      this.height = 48,
      this.grow = 1});

  @override
  Widget build(BuildContext context) {
    final top = monthKm.fold<double>(0, (a, b) => b > a ? b : a);
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
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
                        top == 0 ? 0.06 : 0.06 + 0.94 * grow * monthKm[m] / top,
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
