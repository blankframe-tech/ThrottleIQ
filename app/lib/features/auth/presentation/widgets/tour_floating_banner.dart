import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../screens/onboarding_tour_provider.dart';

/// Pop result the banner hands back to the tour for "Next": the tour, which
/// is awaiting the "Show me" push, advances to the following step.
const String kTourResultNext = 'tour-next';

/// Floating banner shown while a rider inspects a live screen from the tour's
/// "Show me". Keeps the remaining steps one tap away: "Back to tour" returns
/// to the same step, "Next" returns and advances.
///
/// Styled on the palette's ink band (with its own on-ink text tokens) so it
/// stays legible over whatever screen is underneath, in every color mode and
/// brightness.
class TourFloatingBanner extends ConsumerWidget {
  const TourFloatingBanner({super.key});

  /// Returns to the tour. The tour normally sits right under the inspected
  /// screen and is awaiting its result; if the rider navigated away with the
  /// bottom nav (which replaces the stack), reopen the tour at [slide].
  static void _returnToTour(
    BuildContext context,
    WidgetRef ref, {
    required int slide,
    Object? result,
  }) {
    ref.read(activeTourGuideProvider.notifier).state = null;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
    } else {
      context.push('/auth/onboarding?demo=1&slide=$slide');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourState = ref.watch(activeTourGuideProvider);
    if (tourState == null) return const SizedBox.shrink();

    final palette = context.palette;
    final shape = context.shape;
    final l10n = context.l10n;
    final slideIndex = tourState.currentSlideIndex;
    final total = tourState.totalSlides;
    final hasNext = slideIndex < total - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Material(
          key: const ValueKey('tour-banner'),
          color: palette.ink,
          elevation: 6,
          shadowColor: palette.overlayDark,
          // Hairline edge: on dark palettes ink sits close to the page
          // background, and the shadow alone doesn't separate them.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shape.radiusLg),
            side: BorderSide(color: palette.onInkMuted.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thin progress rail across the top edge.
              LinearProgressIndicator(
                value: (slideIndex + 1) / total,
                minHeight: 3,
                backgroundColor: palette.onInkMuted.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation(palette.onInk),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 2, 4),
                child: Row(
                  children: [
                    Icon(Icons.explore_outlined,
                        color: palette.onInk, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tourStepCounter(slideIndex + 1, total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: palette.onInkMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tourState.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: palette.onInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.closeGuide,
                      icon: Icon(Icons.close,
                          size: 20, color: palette.onInkMuted),
                      constraints:
                          const BoxConstraints.tightFor(width: 48, height: 48),
                      onPressed: () {
                        ref.read(activeTourGuideProvider.notifier).state = null;
                      },
                    ),
                  ],
                ),
              ),
              // Actions on their own row so the step title never gets
              // squeezed out on a narrow phone or by longer Bangla labels.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      // Inverse fill (on-ink on ink) rather than the skin's
                      // primary: guaranteed contrast whatever the color mode.
                      child: TextButton(
                        key: const ValueKey('tour-banner-back'),
                        onPressed: () =>
                            _returnToTour(context, ref, slide: slideIndex),
                        style: TextButton.styleFrom(
                          backgroundColor: palette.onInk,
                          foregroundColor: palette.ink,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(shape.radiusMd),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        child: Text(l10n.backTour,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    if (hasNext) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('tour-banner-next'),
                          onPressed: () => _returnToTour(
                            context,
                            ref,
                            slide: slideIndex + 1,
                            result: kTourResultNext,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.onInk,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(shape.radiusMd),
                              side: BorderSide(color: palette.onInkMuted),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          child: Text(l10n.tourNext,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
