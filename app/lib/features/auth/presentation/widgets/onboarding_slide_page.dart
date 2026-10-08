import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../screens/onboarding_manifest.dart';

/// Below this many logical pixels of height the tour switches to its compact
/// layout (smaller spotlight, tighter type) so a 4"/5" phone — or a large
/// text scale — still fits the step without clipping.
const double kTourCompactHeight = 560;

/// Whether the rider asked the OS to cut motion. Read in build, never cached.
bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

// ─── Content ────────────────────────────────────────────────────────────────

/// One tour step's content: the spotlight preview, the title, and the
/// numbered callouts. Navigation chrome (progress, skip, back/next) lives
/// outside the `PageView` in [TourProgressHeader] / [TourControls] so it stays
/// put while the content swipes.
class OnboardingSlidePage extends StatefulWidget {
  const OnboardingSlidePage({super.key, required this.slide});

  final OnboardingSlide slide;

  @override
  State<OnboardingSlidePage> createState() => _OnboardingSlidePageState();
}

class _OnboardingSlidePageState extends State<OnboardingSlidePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.status == AnimationStatus.dismissed) {
      if (_reduceMotion(context)) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Fade + rise for the [index]-th block, staggered so the step reads top
  /// to bottom rather than appearing all at once.
  Widget _staggered(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 0.5);
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, math.min(1, start + 0.6), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final palette = context.palette;
    final accent = slide.accent.resolve(palette);

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < kTourCompactHeight;
      final previewHeight = compact
          ? 170.0
          : (constraints.maxHeight * 0.4).clamp(200.0, 260.0);

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _staggered(
              0,
              TourSpotlightPreview(
                slide: slide,
                height: previewHeight,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            _staggered(
              1,
              Text(
                slide.title,
                style: AppTypography.display(context, compact ? 22 : 26,
                    weight: FontWeight.w800, height: 1.15),
              ),
            ),
            const SizedBox(height: 6),
            _staggered(
              1,
              Text(
                slide.subtitle,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.4,
                  color: palette.textSecondary,
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            for (var i = 0; i < slide.pointers.length; i++)
              _staggered(
                i + 2,
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PointerTile(
                    pointer: slide.pointers[i],
                    accent: accent,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// One numbered callout card.
class _PointerTile extends StatelessWidget {
  const _PointerTile({required this.pointer, required this.accent});

  final SlidePointer pointer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = context.shape;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberBadge(number: pointer.number, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(pointer.icon, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        pointer.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    if (pointer.isBeta) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(shape.radiusSm),
                          border: Border.all(color: palette.textSecondary),
                        ),
                        child: Text(
                          context.l10n.jamLabelBetaTag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pointer.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.accent, this.size = 26});

  final int number;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Tinted fill over the surface, number in body ink: readable whatever
        // the accent's own luminance is.
        color: Color.alphaBlend(accent.withValues(alpha: 0.16), palette.surface),
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
          height: 1,
        ),
      ),
    );
  }
}

// ─── Spotlight preview ──────────────────────────────────────────────────────

/// A schematic of where the step's feature lives: the hero icon under a
/// pulsing spotlight, the numbered callouts orbiting it, a breadcrumb chip,
/// and a miniature of the real bottom navigation with the step's tab lit.
///
/// Drawn entirely from theme tokens (palette, shape, typography), so it
/// matches every color mode, brightness and shape vibe — the old per-feature
/// pixel mockups hardcoded their own colors and drifted from the real UI.
class TourSpotlightPreview extends StatefulWidget {
  const TourSpotlightPreview({
    super.key,
    required this.slide,
    required this.height,
  });

  final OnboardingSlide slide;
  final double height;

  @override
  State<TourSpotlightPreview> createState() => _TourSpotlightPreviewState();
}

class _TourSpotlightPreviewState extends State<TourSpotlightPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final palette = context.palette;
    final accent = slide.accent.resolve(palette);
    const navHeight = 52.0;
    final stageHeight = widget.height - navHeight;
    // Halo (1.9x) plus a pin (22) has to fit under the breadcrumb chip.
    final heroSize = ((stageHeight - 48) / 1.9).clamp(36.0, 92.0);

    return Semantics(
      container: true,
      label: '${slide.location}: ${slide.title}',
      excludeSemantics: true,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.shape.radiusXl),
          child: SizedBox(
            height: widget.height,
            child: Column(
              children: [
                // ── Stage ─────────────────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [
                          accent.withValues(alpha: palette.isDark ? 0.18 : 0.12),
                          palette.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 12,
                          top: 12,
                          right: 12,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _LocationChip(text: slide.location),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: _Spotlight(
                              pulse: _pulse,
                              accent: accent,
                              icon: slide.icon,
                              size: heroSize,
                              // Too tight to orbit pins on a compact stage;
                              // the numbered cards below carry them anyway.
                              pins: heroSize < 52 ? 0 : slide.pointers.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Mini bottom nav ───────────────────────────────────────
                _MiniNavBar(
                  height: navHeight,
                  activeTab: slide.tab,
                  accent: accent,
                  pulse: _pulse,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(context.shape.radiusFull),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_outlined, size: 13, color: palette.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero icon under a breathing spotlight, with the step's numbered callout
/// pins orbiting it.
class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.pulse,
    required this.accent,
    required this.icon,
    required this.size,
    required this.pins,
  });

  final Animation<double> pulse;
  final Color accent;
  final IconData icon;
  final double size;
  final int pins;

  // Pin arc, in radians from 3 o'clock: from about 1 o'clock round to
  // about 4 o'clock.
  static const double _pinStart = -math.pi * 0.4;
  static const double _pinEnd = math.pi * 0.15;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final outer = size * 1.9;
    const pinSize = 22.0;
    return SizedBox(
      width: outer + pinSize,
      height: outer + pinSize,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(pulse.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer halo.
              Container(
                width: outer * (0.92 + 0.08 * t),
                height: outer * (0.92 + 0.08 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.06 + 0.04 * t),
                ),
              ),
              // Inner ring.
              Container(
                width: size * 1.4,
                height: size * 1.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
              ),
              // Lit disc.
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surface,
                  border: Border.all(color: accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25 + 0.15 * t),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(icon, size: size * 0.48, color: accent),
              ),
              // Callout pins, spread over the upper-right arc so they never
              // collide with the breadcrumb chip at the top-left.
              for (var i = 0; i < pins; i++)
                Transform.translate(
                  offset: Offset.fromDirection(
                    _pinStart +
                        i * (_pinEnd - _pinStart) / math.max(1, pins - 1),
                    outer / 2 - 2,
                  ),
                  child: _NumberBadge(
                    number: i + 1,
                    accent: accent,
                    size: pinSize,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Miniature of the app's bottom navigation, with the step's tab spotlit.
class _MiniNavBar extends StatelessWidget {
  const _MiniNavBar({
    required this.height,
    required this.activeTab,
    required this.accent,
    required this.pulse,
  });

  final double height;
  final TourTab activeTab;
  final Color accent;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        children: [
          for (final tab in TourTab.values)
            Expanded(
              child: tab == activeTab
                  ? AnimatedBuilder(
                      animation: pulse,
                      builder: (context, child) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(context.shape.radiusMd),
                          border: Border.all(
                            color: accent.withValues(
                                alpha: 0.55 + 0.45 * pulse.value),
                            width: 1.5,
                          ),
                        ),
                        child: child,
                      ),
                      child: _MiniNavItem(
                        icon: tab.activeIcon,
                        label: tab.label(l10n),
                        iconColor: accent,
                        labelColor: palette.textPrimary,
                        bold: true,
                      ),
                    )
                  : _MiniNavItem(
                      icon: tab.icon,
                      label: tab.label(l10n),
                      iconColor: palette.textTertiary,
                      labelColor: palette.textTertiary,
                    ),
            ),
        ],
      ),
    );
  }
}

class _MiniNavItem extends StatelessWidget {
  const _MiniNavItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.labelColor,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color labelColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Fixed scale: this is a picture of the nav bar, and a large system
          // text size would only push the labels out of the miniature.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

// ─── Chrome ─────────────────────────────────────────────────────────────────

/// Step counter, segmented progress bar, and the skip/exit control.
class TourProgressHeader extends StatelessWidget {
  const TourProgressHeader({
    super.key,
    required this.current,
    required this.total,
    required this.accent,
    required this.onSkip,
    required this.demoMode,
  });

  final int current;
  final int total;
  final Color accent;
  final VoidCallback onSkip;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = context.shape;
    final l10n = context.l10n;
    final duration =
        _reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 320);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tourStepCounter(current + 1, total),
                key: const ValueKey('tour-step-counter'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: palette.textSecondary,
                ),
              ),
            ),
            if (demoMode)
              IconButton(
                key: const ValueKey('tour-skip'),
                tooltip: l10n.exitDemo,
                onPressed: onSkip,
                icon: Icon(Icons.close, color: palette.textSecondary),
              )
            else
              TextButton(
                key: const ValueKey('tour-skip'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: palette.textSecondary,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(l10n.skipTour),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(
          label: l10n.tourStepCounter(current + 1, total),
          excludeSemantics: true,
          child: Row(
            key: const ValueKey('tour-progress'),
            children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    height: i == current ? 6 : 4,
                    margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: i <= current ? accent : palette.border,
                      borderRadius: BorderRadius.circular(shape.radiusFull),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Back / Next (or Finish), plus the "Show me" link when the step has a live
/// screen to open.
class TourControls extends StatelessWidget {
  const TourControls({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    this.onShowMe,
  });

  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onShowMe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duration =
        _reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 220);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reserve the row even when absent so the buttons don't jump between
        // steps with and without a live screen.
        SizedBox(
          height: 48,
          child: AnimatedSwitcher(
            duration: duration,
            child: onShowMe == null
                ? const SizedBox.shrink()
                : Center(
                    child: TextButton.icon(
                      key: const ValueKey('tour-show-me'),
                      onPressed: onShowMe,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.tourShowMeLive,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('tour-back'),
                onPressed: isFirst ? null : onBack,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.tourBack),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const ValueKey('tour-next'),
                onPressed: onNext,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: Text(
                      isLast ? l10n.tourFinish : l10n.tourNext,
                      key: ValueKey(isLast),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
