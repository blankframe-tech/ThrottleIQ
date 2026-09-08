import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../screens/onboarding_manifest.dart';

/// Full-bleed, animated feature spotlight slide.
///
/// Used inside the [OnboardingScreen] PageView for each entry in
/// [kOnboardingSlides]. The slide is intentionally stateless — all
/// animation is driven by the parent's [PageController] via the
/// [pageProgress] value (0.0 = fully off-screen left, 1.0 = centred,
/// 2.0 = fully off-screen right).
///
/// Layout:
/// ```
/// ┌─────────────────────────────────────────┐
/// │  Skip tour (top-right)                  │
/// │                                         │
/// │       [Glowing hero icon — 88dp]        │
/// │                                         │
/// │       TITLE (28sp bold)                 │
/// │       Subtitle (15sp, secondary)        │
/// │                                         │
/// │  ✓ Bullet                               │
/// │  ✓ Bullet                               │
/// │  ✓ Bullet                               │
/// │                                         │
/// │  ● ○ ○ ○ ○ ○ ○  (page dots)            │
/// │                                         │
/// │  [Show me →]       [Got it →]          │
/// └─────────────────────────────────────────┘
/// ```
class OnboardingSlidePage extends StatefulWidget {
  const OnboardingSlidePage({
    super.key,
    required this.slide,
    required this.totalSlides,
    required this.slideIndex,
    required this.onNext,
    required this.onSkip,
    required this.onShowMe,
    required this.isLastSlide,
  });

  final OnboardingSlide slide;
  final int totalSlides;
  final int slideIndex;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onShowMe;
  final bool isLastSlide;

  @override
  State<OnboardingSlidePage> createState() => _OnboardingSlidePageState();
}

class _OnboardingSlidePageState extends State<OnboardingSlidePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _iconScale = CurvedAnimation(parent: _anim, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    _contentFade = CurvedAnimation(parent: _anim, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    // Small delay so the slide-in PageView swipe finishes first.
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final accent = slide.accentColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Skip button ─────────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    'Skip tour',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Hero icon with radial glow ───────────────────────────────
              ScaleTransition(
                scale: _iconScale,
                child: Center(
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(slide.icon, size: 64, color: accent),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Title + subtitle ─────────────────────────────────────────
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slide.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Bullet points ────────────────────────────────────────────
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: slide.bullets.map((bullet) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5, right: 10),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                bullet,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Page indicator dots ──────────────────────────────────────
              _PageDots(
                total: widget.totalSlides,
                current: widget.slideIndex,
                activeColor: accent,
              ),

              const SizedBox(height: 24),

              // ── CTA buttons ──────────────────────────────────────────────
              Row(
                children: [
                  // "Show me" only when a route is provided
                  if (slide.showMeRoute != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onShowMe,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accent.withValues(alpha: 0.6)),
                          foregroundColor: accent,
                        ),
                        child: const Text('Show me'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: slide.showMeRoute != null ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(widget.isLastSlide ? 'Get Riding 🏍️' : 'Got it  →'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small dot-row page indicator.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.total,
    required this.current,
    required this.activeColor,
  });

  final int total;
  final int current;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? activeColor : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
