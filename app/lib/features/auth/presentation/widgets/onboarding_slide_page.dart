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

/// One tour step's content: the real-screen preview, the title, and the
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
      curve:
          Interval(start, math.min(1, start + 0.6), curve: Curves.easeOutCubic),
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
    final accent = tourAccent(palette);

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < kTourCompactHeight;
      final previewHeight =
          compact ? 220.0 : (constraints.maxHeight * 0.58).clamp(280.0, 420.0);

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _staggered(
              0,
              TourScreenPreview(
                slide: slide,
                height: previewHeight,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            _staggered(
              1,
              Text(
                slide.location.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
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
                          borderRadius: BorderRadius.circular(shape.radiusSm),
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
  const _NumberBadge(
      {required this.number, required this.accent, this.size = 26});

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
        color:
            Color.alphaBlend(accent.withValues(alpha: 0.16), palette.surface),
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

// ─── Screen preview ─────────────────────────────────────────────────────────

/// A real capture of the step's screen in a phone-shaped frame, with the
/// step's numbered callouts pinned on the elements they describe.
class TourScreenPreview extends StatelessWidget {
  const TourScreenPreview({
    super.key,
    required this.slide,
    required this.height,
  });

  final OnboardingSlide slide;
  final double height;

  // Width / height of the cropped captures in assets/images/tour_*.jpg.
  static const double _aspect = 540 / 1098;
  static const double _pinSize = 22;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = tourAccent(palette);
    final width = height * _aspect;
    return Center(
      child: Semantics(
        container: true,
        image: true,
        label: '${slide.location}: ${slide.title}',
        excludeSemantics: true,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      slide.screenshot,
                      fit: BoxFit.cover,
                      // Decode at display size, not the asset's full size.
                      cacheWidth:
                          (width * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                    ),
                  ),
                ),
              ),
              for (final p in slide.pointers)
                if (p.at case final at?)
                  Positioned(
                    left: at.dx * width - _pinSize / 2,
                    top: at.dy * height - _pinSize / 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: _NumberBadge(
                        number: p.number,
                        accent: accent,
                        size: _pinSize,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
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
    final duration = _reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 320);

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
    final duration = _reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
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
