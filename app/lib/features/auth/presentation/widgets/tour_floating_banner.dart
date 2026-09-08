import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/onboarding_manifest.dart';
import '../screens/onboarding_tour_provider.dart';

/// Floating banner shown when a rider taps "Show me" in the tour and is
/// viewing an in-app feature screen. Prevents losing the remaining guides
/// and lets the rider return to the tour or advance to the next guide.
class TourFloatingBanner extends ConsumerWidget {
  const TourFloatingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourState = ref.watch(activeTourGuideProvider);
    if (tourState == null) return const SizedBox.shrink();

    final slideIndex = tourState.currentSlideIndex;
    final total = tourState.totalSlides;
    final hasNext = slideIndex < total - 1;
    final slide = kOnboardingSlides[slideIndex];
    final accent = slide.accentColor;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF181D22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.explore, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GUIDE · ${slideIndex + 1} OF $total',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tourState.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                ref.read(activeTourGuideProvider.notifier).state = null;
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.push('/auth/onboarding?demo=1&slide=$slideIndex');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Back to Tour', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            if (hasNext) ...[
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () {
                  final nextIndex = slideIndex + 1;
                  final nextSlide = kOnboardingSlides[nextIndex];
                  ref.read(activeTourGuideProvider.notifier).state = TourGuideState(
                    currentSlideIndex: nextIndex,
                    totalSlides: total,
                    featureKey: nextSlide.featureKey,
                    title: nextSlide.title,
                    showMeRoute: nextSlide.showMeRoute,
                  );
                  if (nextSlide.showMeRoute != null) {
                    context.go(nextSlide.showMeRoute!);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Next →', style: TextStyle(fontSize: 11)),
              ),
            ],
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                ref.read(activeTourGuideProvider.notifier).state = null;
              },
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.close, size: 16, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
