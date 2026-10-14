import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/badges.dart';
import '../../../../shared/widgets/editorial.dart';
import '../badge_l10n.dart';
import '../providers/badge_earned_dates_provider.dart';

/// One badge, up close: big art, how to earn it, earned date or progress.
///
/// Opened from a rung in the ladder sheet (badge_grid.dart). Everything here
/// is local. The "% of riders own this" rarity figure was removed on
/// 2026-10-14: riders can award themselves any badge (CrtiQue_Oct14 B7), so
/// the counts behind it meant nothing.
Future<void> showBadgeDetailSheet(
  BuildContext context, {
  required BadgeFamilyProgress progress,
  required EarnedBadge badge,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.shape.radiusXl),
      ),
    ),
    builder: (_) => BadgeDetailSheet(progress: progress, badge: badge),
  );
}

class BadgeDetailSheet extends ConsumerWidget {
  final BadgeFamilyProgress progress;
  final EarnedBadge badge;

  const BadgeDetailSheet({
    super.key,
    required this.progress,
    required this.badge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final family = progress.family;
    final def = badge.def;
    final earned = badge.earned;

    final earnedAt =
        earned ? ref.watch(badgeEarnedDatesProvider)[def.id] : null;

    final unit = family.localizedUnit(l);
    final name = def.localizedName(l);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingMd,
          AppDimensions.paddingMd,
          AppDimensions.paddingMd,
          AppDimensions.paddingLg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(context.shape.radiusFull),
                ),
              ),
              const SizedBox(height: 20),
              BadgeArt(
                icon: family.icon,
                earned: earned,
                size: 132,
              ),
              const SizedBox(height: 16),
              Text(
                '${def.tier.localizedLabel(l)} · ${family.localizedName(l)}'
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: earned ? p.primary : p.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.center,
                style: display(context, 24, letterSpacing: 0),
              ),
              const SizedBox(height: 10),
              _StatusLine(earned: earned, earnedAt: earnedAt),
              const SizedBox(height: 20),
              if (!earned) ...[
                _ProgressBlock(
                  value: progress.value,
                  threshold: def.threshold,
                  unit: unit,
                ),
                const SizedBox(height: 16),
              ],
              _Section(
                label: l.badgeHowToEarn,
                footer: family.localizedAbout(l),
                child: Text(
                  family.localizedRequirementFor(l, def.threshold),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (earned) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Share.share(l.badgeShareText(name)),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(l.badgeShareAction),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final bool earned;
  final DateTime? earnedAt;

  const _StatusLine({required this.earned, required this.earnedAt});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final color = earned ? p.primary : p.textTertiary;
    final text = !earned
        ? l.badgeLockedStatus
        : earnedAt == null
            ? l.badgeEarnedStatus
            : l.badgeEarnedOn(
                DateFormat('d MMM y', kNumericLocale).format(earnedAt!),
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.shape.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            earned ? Icons.verified_outlined : Icons.lock_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final num value;
  final num threshold;
  final String unit;

  const _ProgressBlock({
    required this.value,
    required this.threshold,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final fraction =
        threshold <= 0 ? 0.0 : (value / threshold).clamp(0.0, 1.0).toDouble();
    final remaining = threshold - value;

    return EditorialCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.badgeProgressFraction(
                    formatBadgeValue(value),
                    formatBadgeValue(threshold),
                    unit,
                  ),
                  style: display(context, 16, letterSpacing: 0),
                ),
              ),
              Text(
                '${(fraction * 100).floor()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          EditorialProgress(fraction, height: 8),
          if (remaining > 0) ...[
            const SizedBox(height: 8),
            Text(
              l.badgeProgressToGo(formatBadgeValue(remaining), unit),
              style: TextStyle(fontSize: 12, color: p.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  final String? footer;

  const _Section({required this.label, required this.child, this.footer});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: EditorialCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialLabel(label),
            const SizedBox(height: 8),
            child,
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(
                footer!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The badge itself, large: the family glyph in a ring.
///
/// Earned badges arrive with a one-shot celebration (an elastic pop, a burst
/// of sparks and a glow that settles) and a light haptic tap. Locked badges
/// are a muted ring with a lock. All motion is skipped when the platform asks
/// for reduced motion.
class BadgeArt extends StatefulWidget {
  final IconData icon;
  final bool earned;
  final double size;

  const BadgeArt({
    super.key,
    required this.icon,
    required this.earned,
    this.size = 132,
  });

  @override
  State<BadgeArt> createState() => _BadgeArtState();
}

class _BadgeArtState extends State<BadgeArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.earned && !reduceMotion) {
      _celebrate.forward();
      HapticFeedback.lightImpact();
    } else {
      _celebrate.value = 1;
    }
  }

  @override
  void dispose() {
    _celebrate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final earned = widget.earned;
    final ring = earned ? [p.primary, p.primary] : [p.border, p.border];
    final glow = earned ? p.primary : null;
    final size = widget.size;

    return SizedBox(
      width: size * 1.5,
      height: size * 1.25,
      child: AnimatedBuilder(
        animation: _celebrate,
        builder: (context, _) {
          final t = _celebrate.value;
          final pop = Curves.elasticOut.transform(
            const Interval(0, 0.75).transform(t),
          );
          final scale = earned ? 0.6 + 0.4 * pop : 1.0;
          // Glow flares on arrival, then settles to a steady halo.
          final flare = earned ? math.sin(math.pi * t.clamp(0.0, 1.0)) : 0.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (earned && t < 1)
                CustomPaint(
                  size: Size(size * 1.5, size * 1.25),
                  painter: _SparkBurstPainter(
                    progress: const Interval(0.05, 0.9).transform(t),
                    colors: [glow!, p.primary, p.secondary, p.attention],
                  ),
                ),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: glow == null
                        ? null
                        : [
                            BoxShadow(
                              color: glow.withValues(
                                alpha: 0.28 + 0.27 * flare,
                              ),
                              blurRadius: 18 + 22 * flare,
                              spreadRadius: 1 + 4 * flare,
                            ),
                          ],
                  ),
                  child: Container(
                    padding: EdgeInsets.all(size * 0.055),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: ring),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: earned
                            ? Color.alphaBlend(
                                (glow ?? p.primary).withValues(alpha: 0.14),
                                p.surface,
                              )
                            : p.surfaceVariant,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            widget.icon,
                            size: size * 0.42,
                            color: earned
                                ? (glow ?? p.primary)
                                : p.textTertiary.withValues(alpha: 0.6),
                          ),
                          if (!earned)
                            Positioned(
                              right: size * 0.16,
                              bottom: size * 0.16,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.surface,
                                  border: Border.all(color: p.border),
                                ),
                                child: Icon(
                                  Icons.lock_outline,
                                  size: size * 0.13,
                                  color: p.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sparks flying outward from the badge and fading — the celebratory burst.
class _SparkBurstPainter extends CustomPainter {
  final double progress; // 0..1
  final List<Color> colors;

  const _SparkBurstPainter({required this.progress, required this.colors});

  static const int _sparks = 18;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.62;
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = 1 - Curves.easeIn.transform(progress);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _sparks; i++) {
      // Deterministic jitter so every opening looks the same.
      final angle = (i / _sparks) * 2 * math.pi + (i.isEven ? 0.12 : -0.08);
      final reach = maxR * (0.7 + 0.3 * ((i * 37) % 10) / 10);
      final r = reach * eased;
      final pos = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      paint.color = colors[i % colors.length].withValues(alpha: fade);
      canvas.drawCircle(
        pos,
        (i % 3 == 0 ? 3.2 : 2.2) * (1 - 0.4 * eased),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkBurstPainter old) =>
      old.progress != progress || old.colors != colors;
}
