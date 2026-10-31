import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/year_in_review.dart';
import 'year_review_card.dart';

/// One page of the year-in-review story, drawn on the same fixed 360x640
/// canvas as [YearCard] so every page exports as a 1080x1920 image.
///
/// [t] (0-1) drives the entrance: text rises in, numbers count up, charts
/// grow. The screen passes 1 when exporting, under reduced motion, and with
/// a screen reader, so those always see the finished page.
class YearStorySlide extends StatelessWidget {
  const YearStorySlide({
    super.key,
    required this.slide,
    required this.review,
    required this.t,
    this.bikeName,
  });

  final StorySlide slide;
  final YearInReview review;
  final String? bikeName;
  final double t;

  @override
  Widget build(BuildContext context) {
    if (slide == StorySlide.summary) {
      return YearCard(review: review, bikeName: bikeName);
    }
    // A fixed canvas: system text size would overflow it, and the preview
    // scales as a whole anyway.
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: YearCard.size,
        child: _Page(slide: slide, r: review, bikeName: bikeName, t: t),
      ),
    );
  }
}

/// Fixed colours per page, never the rider's skin: a shared image looks the
/// same from every phone. Every [muted] clears 4.5:1 on its [bg].
class _Look {
  const _Look(this.bg, this.fg, this.muted, this.accent, {this.bg2});
  final Color bg;
  final Color? bg2;
  final Color fg;
  final Color muted;
  final Color accent;
}

const _ink = Color(0xFF0A0A0A);
const _inkMuted = Color(0xFF141414);
const _paper = Color(0xFFF4F4F4);
const _paperMuted = Color(0xFFB4B4B4);
const _lime = Color(0xFFC8FF3D);

const _looks = <StorySlide, _Look>{
  StorySlide.cover: _Look(Color(0xFF000000), _paper, _paperMuted, _lime),
  StorySlide.distance: _Look(_lime, _ink, _inkMuted, _ink),
  StorySlide.days: _Look(Color(0xFF0E0E10), _paper, _paperMuted, _lime),
  StorySlide.time:
      _Look(Color(0xFF2B0A3D), _paper, _paperMuted, Color(0xFFE88CFF)),
  StorySlide.month: _Look(Color(0xFFFF7A45), _ink, _inkMuted, _ink),
  StorySlide.weekday:
      _Look(Color(0xFF0B1D3A), _paper, _paperMuted, Color(0xFF5CE1E6)),
  StorySlide.longest: _Look(_paper, _ink, _inkMuted, Color(0xFFD633FF)),
  StorySlide.topSpeed:
      _Look(Color(0xFF000000), _paper, _paperMuted, Color(0xFFFF7A45)),
  StorySlide.climb: _Look(Color(0xFF0D2B22), _paper, _paperMuted, _lime),
  StorySlide.lean:
      _Look(Color(0xFF161616), _paper, _paperMuted, Color(0xFFE88CFF)),
  StorySlide.bike: _Look(Color(0xFFD633FF), _ink, _inkMuted, _ink),
  StorySlide.growth: _Look(Color(0xFF42BE65), _ink, _inkMuted, _ink),
};

const _clockLooks = <RiderClock, _Look>{
  RiderClock.earlyBird:
      _Look(Color(0xFFFFD86B), _ink, _inkMuted, _ink, bg2: Color(0xFFFFB38A)),
  RiderClock.daylight:
      _Look(Color(0xFF8FD3FF), _ink, _inkMuted, _ink, bg2: Color(0xFFE6F6FF)),
  RiderClock.sunsetChaser:
      _Look(Color(0xFFFF9A5A), _ink, _inkMuted, _ink, bg2: Color(0xFFFF5E7E)),
  RiderClock.nightOwl: _Look(
      Color(0xFF0A0F2C), _paper, _paperMuted, Color(0xFF9DB4FF),
      bg2: Color(0xFF1C1145)),
};

const _clockIcons = <RiderClock, IconData>{
  RiderClock.earlyBird: Icons.coffee_rounded,
  RiderClock.daylight: Icons.wb_sunny_rounded,
  RiderClock.sunsetChaser: Icons.wb_twilight_rounded,
  RiderClock.nightOwl: Icons.nightlight_round,
};

/// 0-1 progress of [t] through the window [a, b], eased.
double _iv(double t, double a, double b) =>
    Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

// Digits stay Western in Bangla too, per core/i18n/numeric_locale.dart.
final _num = NumberFormat('#,##0', kNumericLocale);
final _dec = NumberFormat('#,##0.#', kNumericLocale);

/// Equator length, for "around the Earth".
const _earthKm = 40075.0;

/// Dhaka to Cox's Bazar by road, rounded.
const _coxKm = 400.0;
const _everestM = 8849.0;

class _Page extends StatelessWidget {
  const _Page(
      {required this.slide,
      required this.r,
      required this.bikeName,
      required this.t});

  final StorySlide slide;
  final YearInReview r;
  final String? bikeName;
  final double t;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clock = r.riderClock;
    final look = slide == StorySlide.clock && clock != null
        ? _clockLooks[clock.$1]!
        : _looks[slide] ?? _looks[StorySlide.cover]!;
    final lang = Localizations.localeOf(context).toLanguageTag();
    String date(DateTime d) => '${d.day} ${DateFormat.MMMM(lang).format(d)}';
    final counted = _iv(t, 0, 0.7); // count-up and chart growth

    Text line(String s, {double size = 15, Color? color}) => Text(s,
        style: TextStyle(
            fontSize: size,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: color ?? look.muted));

    final _Content c = switch (slide) {
      StorySlide.distance => _Content(
          kicker: l10n.yearStoryDistanceKicker,
          hero: _dec.format(r.distanceKm * counted),
          unit: l10n.distanceStatLabel,
          lines: [
            if (r.distanceKm >= _earthKm)
              l10n.yearStoryEarthLaps(_dec.format(r.distanceKm / _earthKm))
            else if (r.distanceKm >= _earthKm / 1000)
              l10n.yearStoryEarthShare(
                  _dec.format(r.distanceKm / _earthKm * 100)),
            if (r.distanceKm >= _coxKm)
              l10n.yearStoryCoxTrips(_dec.format(r.distanceKm / _coxKm)),
          ],
          art: CustomPaint(
              painter: _GlobePainter(
                  r.distanceKm / _earthKm * counted, look.fg, look.bg)),
        ),
      StorySlide.days => _Content(
          kicker: l10n.yearStoryRidesKicker,
          hero: _num.format((r.rideCount * counted).round()),
          lines: [
            l10n.yearStoryActiveDays(r.activeDays),
            if (r.longestStreakDays >= 2)
              l10n.yearStoryStreak(r.longestStreakDays),
          ],
          art: CustomPaint(
              painter: _DayGridPainter(r.dayKm, r.year, look.accent,
                  look.fg.withValues(alpha: 0.12), counted)),
        ),
      StorySlide.time => () {
          final hours = r.rideSeconds / 3600;
          return _Content(
            kicker: l10n.yearStoryTimeKicker,
            hero: (hours >= 10 ? _num : _dec).format(hours * counted),
            unit: l10n.yearStoryHoursUnit,
            lines: [
              if (hours >= 24) l10n.yearStoryTimeDays(_dec.format(hours / 24)),
              l10n.yearStoryAvgRide(
                  _num.format(r.rideSeconds / 60 / r.rideCount)),
            ],
            art: CustomPaint(
                painter: _RingsPainter(hours * counted / 24, look.accent,
                    look.fg.withValues(alpha: 0.1))),
          );
        }(),
      StorySlide.month => _Content(
          kicker: l10n.yearInReviewBusiestMonth,
          word: true,
          hero: DateFormat.MMMM(lang).format(DateTime(r.year, r.busiestMonth!)),
          lines: [
            l10n.yearStoryMonthKm(
                '${_dec.format(r.monthKm[r.busiestMonth! - 1])} ${l10n.distanceStatLabel}'),
          ],
          art: Align(
            alignment: Alignment.bottomCenter,
            child: MonthBars(r.monthKm,
                highlight: r.busiestMonth,
                color: look.accent,
                muted: look.fg.withValues(alpha: 0.2),
                height: 240,
                grow: counted),
          ),
        ),
      StorySlide.weekday => () {
          final day = r.favouriteWeekday!;
          // 2024-01-01 was a Monday: any weekday's name, in the UI language.
          String name(int wd, String pattern) =>
              DateFormat(pattern, lang).format(DateTime(2024, 1, wd));
          final first =
              MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sun
          final order = [for (var i = 0; i < 7; i++) (first + i + 6) % 7 + 1];
          final top = r.weekdayRides.reduce(math.max);
          return _Content(
            kicker: l10n.yearStoryWeekdayKicker,
            word: true,
            hero: name(day, 'EEEE'),
            lines: [
              l10n.yearStoryWeekdayShare(
                  _num.format(r.weekdayRides[day - 1] / r.rideCount * 100)),
            ],
            art: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final wd in order)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              widthFactor: 1,
                              heightFactor: 0.05 +
                                  0.95 * counted * r.weekdayRides[wd - 1] / top,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: wd == day
                                      ? look.accent
                                      : look.fg.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(name(wd, 'E'),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: wd == day ? look.fg : look.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }(),
      StorySlide.clock => () {
          final (kind, share) = clock!;
          final pct = _num.format(share * 100);
          final (title, sub) = switch (kind) {
            RiderClock.earlyBird => (
                l10n.yearStoryEarlyBird,
                l10n.yearStoryEarlyBirdLine(pct)
              ),
            RiderClock.daylight => (
                l10n.yearStoryDaylight,
                l10n.yearStoryDaylightLine(pct)
              ),
            RiderClock.sunsetChaser => (
                l10n.yearStorySunset,
                l10n.yearStorySunsetLine(pct)
              ),
            RiderClock.nightOwl => (
                l10n.yearStoryNightOwl,
                l10n.yearStoryNightOwlLine(pct)
              ),
          };
          return _Content(
            kicker: l10n.yearStoryClockKicker,
            word: true,
            hero: title,
            lines: [sub],
            art: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                      painter: _ClockPainter(r.hourRides, look.accent,
                          look.fg.withValues(alpha: 0.15), look.muted, counted,
                          stars: kind == RiderClock.nightOwl)),
                ),
                Icon(_clockIcons[kind], size: 44, color: look.fg),
              ],
            ),
          );
        }(),
      StorySlide.longest => () {
          final avg = r.distanceKm / r.rideCount;
          final times = avg > 0 ? r.longestRideKm / avg : 0.0;
          return _Content(
            kicker: l10n.yearInReviewLongestRide,
            hero: _dec.format(r.longestRideKm * counted),
            unit: l10n.distanceStatLabel,
            lines: [
              if (r.longestRideDate != null)
                l10n.yearStoryOnDate(date(r.longestRideDate!)),
              if (r.longestRideRoute != null)
                l10n.yearStoryRoute(r.longestRideRoute!),
              if (times >= 1.5) l10n.yearStoryLongestVsAvg(_dec.format(times)),
            ],
            art: CustomPaint(painter: _RoadPainter(look.accent, counted)),
          );
        }(),
      StorySlide.topSpeed => _Content(
          kicker: l10n.topSpeed,
          hero: _num.format(r.topSpeedKmh * counted),
          unit: 'km/h',
          lines: [
            if (r.topSpeedDate != null)
              l10n.yearStoryOnDate(date(r.topSpeedDate!)),
          ],
          art: CustomPaint(
              painter: _GaugePainter(r.topSpeedKmh * counted, look.accent,
                  look.fg.withValues(alpha: 0.15), look.muted)),
        ),
      StorySlide.climb => _Content(
          kicker: l10n.yearStoryClimbKicker,
          hero: _num.format(r.climbM * counted),
          unit: l10n.yearStoryMetresUnit,
          lines: [
            r.climbM >= _everestM
                ? l10n.yearStoryEverestTimes(_dec.format(r.climbM / _everestM))
                : l10n.yearStoryEverestShare(
                    _num.format(r.climbM / _everestM * 100)),
          ],
          art: CustomPaint(
              painter: _MountainPainter(r.climbM / _everestM * counted,
                  look.accent, look.fg.withValues(alpha: 0.14))),
        ),
      StorySlide.lean => _Content(
          kicker: l10n.yearStoryLeanKicker,
          hero: '${_num.format((r.maxLeanDeg ?? 0) * counted)}°',
          lines: [l10n.yearStoryLeanNote],
          art: CustomPaint(
              painter: _LeanPainter((r.maxLeanDeg ?? 0) * counted, look.accent,
                  look.fg.withValues(alpha: 0.15), look.fg)),
        ),
      StorySlide.bike => _Content(
          kicker: l10n.yearInReviewFavouriteBike,
          word: true,
          hero: bikeName ?? '',
          lines: [
            l10n.yearStoryBikeShare(
                r.favouriteBikeRides.toString(), r.rideCount.toString()),
          ],
          art: CustomPaint(
              painter: _WheelPainter(
                  t * math.pi * 1.5, look.fg, look.fg.withValues(alpha: 0.25))),
        ),
      StorySlide.growth => () {
          final change = r.changeVsPrevious ?? 0;
          final prev = '${r.year - 1}';
          return _Content(
            kicker: l10n.yearStoryGrowthKicker,
            hero: '+${_num.format(change * 100 * counted)}%',
            lines: [
              r.inProgress
                  ? l10n.yearStoryGrowthMoreSoFar(prev)
                  : l10n.yearStoryGrowthMore(prev),
            ],
            art: _GrowthBars(
              before: r.previousKm ?? 0,
              now: r.distanceKm,
              labels: (prev, '${r.year}'),
              look: look,
              grow: counted,
            ),
          );
        }(),
      // Cover (and the summary, which never reaches here).
      _ => _Content(
          kicker: l10n.yearStoryCoverSub,
          hero: '${r.year}',
          lines: [
            r.inProgress
                ? l10n.yearInReviewHeadingSoFar('${r.year}')
                : l10n.yearInReviewHeading('${r.year}'),
          ],
          art: CustomPaint(painter: _SpeedLinesPainter(look.accent, t)),
        ),
    };

    Widget rise(int i, Widget child) {
      final v = _iv(t, 0.06 * i, 0.06 * i + 0.3);
      return Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      );
    }

    final heroIsWord = c.word;
    return Container(
      key: Key('year_story_${slide.name}'),
      decoration: BoxDecoration(
        // Square: rounded corners export as transparent pixels. The preview
        // is rounded outside.
        color: look.bg,
        gradient: look.bg2 == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [look.bg, look.bg2!]),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rise(
              0,
              Text(c.kicker.toUpperCase(),
                  style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      color: look.fg))),
          const SizedBox(height: 16),
          Expanded(
            child: ExcludeSemantics(
                child: Opacity(
                    opacity: _iv(t, 0, 0.2),
                    // Full width: the column's start alignment would
                    // otherwise give a painter none.
                    child: SizedBox.expand(child: c.art))),
          ),
          const SizedBox(height: 16),
          rise(
            1,
            MergeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  // Words wrap to at most two lines; numbers never wrap.
                  constraints:
                      BoxConstraints(maxWidth: heroIsWord ? 312 : 2000),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: c.hero,
                          style: display(
                              context,
                              heroIsWord
                                  ? 52
                                  : (slide == StorySlide.cover ? 120 : 96),
                              height: 1.0,
                              letterSpacing: -2,
                              color: slide == StorySlide.cover
                                  ? look.accent
                                  : look.fg)),
                      if (c.unit != null)
                        TextSpan(
                            text: ' ${c.unit}',
                            style: display(context, 28, color: look.fg)),
                    ]),
                    maxLines: heroIsWord ? 2 : 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < c.lines.length; i++)
            rise(
                2 + i,
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: line(c.lines[i],
                      size: i == 0 ? 17 : 15,
                      color: i == 0 ? look.fg : look.muted),
                )),
          const SizedBox(height: 22),
          _Footer(look: look),
        ],
      ),
    );
  }
}

class _Content {
  const _Content(
      {required this.kicker,
      required this.hero,
      required this.art,
      this.unit,
      this.word = false,
      this.lines = const []});
  final String kicker;

  /// The hero is a word (a month, a name), not a figure: smaller, may wrap.
  final bool word;
  final String hero;
  final String? unit;
  final List<String> lines;
  final Widget art;
}

/// Brand and the way back to the app: a single shared page travels alone.
class _Footer extends StatelessWidget {
  const _Footer({required this.look});
  final _Look look;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child:
              Image.asset('assets/images/app_icon.png', width: 22, height: 22),
        ),
        const SizedBox(width: 8),
        Text('ThrottleIQ', style: display(context, 15, color: look.fg)),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(context.l10n.yearStoryFooter,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: look.muted)),
          ),
        ),
      ],
    );
  }
}

class _GrowthBars extends StatelessWidget {
  const _GrowthBars(
      {required this.before,
      required this.now,
      required this.labels,
      required this.look,
      required this.grow});
  final double before;
  final double now;
  final (String, String) labels;
  final _Look look;
  final double grow;

  @override
  Widget build(BuildContext context) {
    final top = math.max(before, now);
    Widget bar(double km, String label, Color color) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${_dec.format(km)} ${context.l10n.distanceStatLabel}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: look.fg)),
              const SizedBox(height: 6),
              Flexible(
                child: FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: top == 0 ? 0.05 : 0.05 + 0.95 * grow * km / top,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: display(context, 18, color: look.fg)),
            ],
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bar(before, labels.$1, look.fg.withValues(alpha: 0.25)),
        const SizedBox(width: 24),
        bar(now, labels.$2, look.fg),
      ],
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────
// Decorative only: every figure they draw is also stated in words.

/// A wireframe globe with an orbit arc for the share of a lap ridden.
class _GlobePainter extends CustomPainter {
  _GlobePainter(this.laps, this.color, this.bg);
  final double laps;
  final Color color;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 18;
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.5);
    canvas.drawCircle(c, r * 0.82, thin);
    for (final f in [0.3, 0.62]) {
      canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 1.64 * f, height: r * 1.64),
          thin);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 1.64, height: r * 1.64 * f),
          thin);
    }
    final orbit = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = color.withValues(alpha: 0.12));
    final sweep = 2 * math.pi * math.min(laps, 1);
    canvas.drawArc(
        orbit,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = color);
    final end = c +
        Offset(math.cos(-math.pi / 2 + sweep), math.sin(-math.pi / 2 + sweep)) *
            r;
    canvas.drawCircle(end, 11, Paint()..color = color);
    canvas.drawCircle(end, 5, Paint()..color = bg);
  }

  @override
  bool shouldRepaint(_GlobePainter old) => old.laps != laps;
}

/// A dot per day of the year: a row per month, brighter for more km.
class _DayGridPainter extends CustomPainter {
  _DayGridPainter(this.dayKm, this.year, this.on, this.off, this.grow);
  final List<double> dayKm;
  final int year;
  final Color on;
  final Color off;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    if (dayKm.isEmpty) return;
    final top = dayKm.reduce(math.max);
    final pitch = math.min(size.width / 31, size.height / 12);
    final dot = pitch * 0.36;
    final origin =
        Offset((size.width - pitch * 31) / 2, (size.height - pitch * 12) / 2);
    final paint = Paint();
    var i = 0;
    for (var m = 0; m < 12; m++) {
      final days = DateTime.utc(year, m + 2, 0).day;
      final shown = (m + 1) / 12 <= grow + 1 / 12;
      for (var d = 0; d < days; d++, i++) {
        final km = i < dayKm.length ? dayKm[i] : 0.0;
        paint.color = km > 0 && shown
            ? Color.lerp(on.withValues(alpha: 0.45), on, km / top)!
            : off;
        canvas.drawCircle(origin + Offset(pitch * (d + 0.5), pitch * (m + 0.5)),
            km > 0 && shown ? dot * 1.15 : dot * 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DayGridPainter old) => old.grow != grow;
}

/// One ring per 24 hours ridden, innermost first, the last one partial.
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.days, this.color, this.track);
  final double days;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = math.min(size.width, size.height) / 2 - 8;
    const rings = 8;
    final step = maxR / (rings + 1);
    final stroke = step * 0.55;
    // Past eight days, each ring stands for more than one.
    final perRing = days <= rings ? 1.0 : (days / rings).ceilToDouble();
    final filled = days / perRing;
    for (var i = 0; i < rings; i++) {
      final rect = Rect.fromCircle(center: c, radius: step * (i + 1.5));
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, 0, 2 * math.pi, false, p..color = track);
      final f = (filled - i).clamp(0.0, 1.0);
      if (f > 0) {
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * f, false,
            p..color = color.withValues(alpha: 0.55 + 0.45 * (i + 1) / rings));
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.days != days;
}

/// Rides per starting hour as 24 spokes around a dial; 0, 6, 12, 18 marked.
class _ClockPainter extends CustomPainter {
  _ClockPainter(this.hours, this.color, this.track, this.label, this.grow,
      {required this.stars});
  final List<int> hours;
  final Color color;
  final Color track;
  final Color label;
  final double grow;
  final bool stars;

  @override
  void paint(Canvas canvas, Size size) {
    if (stars) {
      final rnd = math.Random(7);
      final p = Paint()..color = label.withValues(alpha: 0.6);
      for (var i = 0; i < 40; i++) {
        canvas.drawCircle(
            Offset(
                rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
            rnd.nextDouble() * 1.4 + 0.4,
            p);
      }
    }
    final c = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2 - 22;
    final inner = outer * 0.36;
    final top = hours.reduce(math.max);
    final spoke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2 * math.pi * inner / 24 * 0.62;
    for (var h = 0; h < 24; h++) {
      final a = -math.pi / 2 + h / 24 * 2 * math.pi;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * inner, c + dir * outer, spoke..color = track);
      if (hours[h] > 0 && top > 0) {
        final len = (outer - inner) * hours[h] / top * grow;
        canvas.drawLine(
            c + dir * inner, c + dir * (inner + len), spoke..color = color);
      }
    }
    for (final h in [0, 6, 12, 18]) {
      final a = -math.pi / 2 + h / 24 * 2 * math.pi;
      final tp = TextPainter(
        text: TextSpan(
            text: '$h',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: label)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          c +
              Offset(math.cos(a), math.sin(a)) * (outer + 13) -
              Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.grow != grow;
}

/// A winding road drawn from the horizon down, dashes in the middle.
class _RoadPainter extends CustomPainter {
  _RoadPainter(this.color, this.grow);
  final Color color;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.55, 0)
      ..cubicTo(w * 1.05, h * 0.2, w * -0.1, h * 0.38, w * 0.45, h * 0.55)
      ..cubicTo(w * 0.95, h * 0.7, w * 0.05, h * 0.82, w * 0.3, h);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * grow);
    canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 34
          ..strokeCap = StrokeCap.round
          ..color = color);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;
    for (var d = 8.0; d < metric.length * grow; d += 22) {
      canvas.drawPath(metric.extractPath(d, d + 10), dash);
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.grow != grow;
}

/// A 240° speedometer with its needle on [kmh].
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.kmh, this.color, this.track, this.label);
  final double kmh;
  final Color color;
  final Color track;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset(0, size.height * 0.08));
    final r = math.min(size.width, size.height) / 2 - 10;
    const start = math.pi * 5 / 6, sweep = math.pi * 4 / 3;
    // Scale to the next 20 above the speed, never below 160.
    final scale = math.max(160, ((kmh / 20).ceil() + 1) * 20).toDouble();
    final rect = Rect.fromCircle(center: c, radius: r);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, arc..color = track);
    final f = (kmh / scale).clamp(0.0, 1.0);
    canvas.drawArc(rect, start, sweep * f, false, arc..color = color);
    final tick = Paint()
      ..strokeWidth = 2
      ..color = label;
    for (var i = 0; i <= 8; i++) {
      final a = start + sweep * i / 8;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r - 22), c + d * (r - 32), tick);
    }
    final a = start + sweep * f;
    canvas.drawLine(
        c,
        c + Offset(math.cos(a), math.sin(a)) * (r - 26),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color);
    canvas.drawCircle(c, 10, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.kmh != kmh;
}

/// A mountain filled from the foot to the share of Everest climbed.
class _MountainPainter extends CustomPainter {
  _MountainPainter(this.everests, this.color, this.track);
  final double everests;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final mountain = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.22, h * 0.45)
      ..lineTo(w * 0.34, h * 0.58)
      ..lineTo(w * 0.58, h * 0.06)
      ..lineTo(w * 0.78, h * 0.5)
      ..lineTo(w * 0.86, h * 0.4)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(mountain, Paint()..color = track);
    final f = everests.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, h - (h * 0.94) * f, w, h));
    canvas.drawPath(mountain, Paint()..color = color);
    canvas.restore();
    if (everests >= 1) {
      final peak = Offset(w * 0.58, h * 0.06);
      final pole = Paint()
        ..strokeWidth = 3
        ..color = color;
      canvas.drawLine(peak, peak - const Offset(0, 34), pole);
      canvas.drawPath(
          Path()
            ..moveTo(peak.dx, peak.dy - 34)
            ..lineTo(peak.dx + 22, peak.dy - 27)
            ..lineTo(peak.dx, peak.dy - 20)
            ..close(),
          Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_MountainPainter old) => old.everests != everests;
}

/// A protractor with the bike leaned over by [deg] degrees.
class _LeanPainter extends CustomPainter {
  _LeanPainter(this.deg, this.color, this.track, this.fg);
  final double deg;
  final Color color;
  final Color track;
  final Color fg;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height - 12);
    final r = math.min(size.width / 2, size.height) - 24;
    final rect = Rect.fromCircle(center: base, radius: r);
    canvas.drawArc(rect, math.pi, math.pi, true, Paint()..color = track);
    final a = deg * math.pi / 180;
    canvas.drawArc(rect, -math.pi / 2, a, true,
        Paint()..color = color.withValues(alpha: 0.85));
    canvas.drawLine(
        base.translate(-r - 8, 0),
        base.translate(r + 8, 0),
        Paint()
          ..strokeWidth = 3
          ..color = fg);
    final tip = base + Offset(math.sin(a), -math.cos(a)) * r;
    canvas.drawLine(
        base,
        tip,
        Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = fg);
    canvas.drawCircle(base, 9, Paint()..color = fg);
  }

  @override
  bool shouldRepaint(_LeanPainter old) => old.deg != deg;
}

/// A turning wheel: tyre, rim and spokes.
class _WheelPainter extends CustomPainter {
  _WheelPainter(this.turn, this.color, this.soft);
  final double turn;
  final Color color;
  final Color soft;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 10;
    canvas.drawCircle(
        c,
        r - 14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28
          ..color = color);
    canvas.drawCircle(
        c,
        r - 38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = soft);
    final spoke = Paint()
      ..strokeWidth = 3
      ..color = color;
    for (var i = 0; i < 12; i++) {
      final a = turn + i * math.pi / 6;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * 16,
          c + Offset(math.cos(a), math.sin(a)) * (r - 38), spoke);
    }
    canvas.drawCircle(c, 18, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.turn != turn;
}

/// Streaks rushing past, for the cover.
class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter(this.color, this.t);
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    for (var i = 0; i < 22; i++) {
      final y = rnd.nextDouble() * size.height;
      final len = 40 + rnd.nextDouble() * 160;
      final speed = 0.6 + rnd.nextDouble();
      final x = (rnd.nextDouble() * size.width * 2 - t * size.width * speed) %
              (size.width + len) -
          len;
      canvas.drawLine(
          Offset(x, y),
          Offset(x + len, y),
          Paint()
            ..strokeWidth = 1 + rnd.nextDouble() * 4
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: 0.15 + rnd.nextDouble() * 0.6));
    }
  }

  @override
  bool shouldRepaint(_SpeedLinesPainter old) => old.t != t;
}
