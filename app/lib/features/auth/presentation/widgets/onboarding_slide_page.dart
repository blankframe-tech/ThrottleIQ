import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../screens/onboarding_manifest.dart';
import 'onboarding_ui_mockups.dart';

/// Full-bleed, animated feature spotlight slide with real UI mockup and callout pointers.
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
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _contentFade = CurvedAnimation(parent: _anim, curve: const Interval(0.2, 1.0, curve: Curves.easeOut));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top header bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(slide.icon, size: 14, color: accent),
                        const SizedBox(width: 5),
                        Text(
                          'GUIDE ${widget.slideIndex + 1} OF ${widget.totalSlides}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onSkip,
                    child: Text(
                      'Skip tour',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Title & Subtitle ──
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slide.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slide.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Centerpiece: UI Mockup with Pointer Pins ──
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: OnboardingUiMockup(
                    featureKey: slide.featureKey,
                    accentColor: accent,
                    pointers: slide.pointers,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Interactive Pointers Breakdown ──
              Expanded(
                child: SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: slide.pointers.isNotEmpty
                            ? slide.pointers.map((p) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        margin: const EdgeInsets.only(top: 2, right: 8),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.18),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: accent, width: 1.2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${p.number}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '${p.title}: ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              TextSpan(
                                                text: p.description,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList()
                            : slide.bullets.map((b) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 5, right: 8),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                      ),
                                      Expanded(
                                        child: Text(b, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Dots Indicator ──
              _PageDots(
                total: widget.totalSlides,
                current: widget.slideIndex,
                activeColor: accent,
              ),
              const SizedBox(height: 14),

              // ── Action Buttons ──
              Row(
                children: [
                  if (slide.showMeRoute != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShowMe,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Show me'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accent.withValues(alpha: 0.6)),
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(widget.isLastSlide ? 'Get Riding 🏍️' : 'Got it  →'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
