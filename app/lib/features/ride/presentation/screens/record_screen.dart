import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/motorcycle_quotes.dart';
import '../../../../core/utils/greetings.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../garage/presentation/widgets/bike_photo.dart';
import '../../../social/presentation/providers/notification_providers.dart';
import '../../../social/presentation/widgets/ride_with_friends_button.dart';
import '../providers/ride_recording_provider.dart';

/// Picked once per app session (Riverpod `Provider`s are computed lazily and
/// cached for the container's lifetime, so this stays fixed across rebuilds
/// within one app open — e.g. RecordScreen re-rendering while a ride's
/// speed/distance update — but is different again next cold start) rather
/// than "Your ride, smarter." always being the same line.
final dashboardQuoteProvider = Provider<(String, String)>((ref) {
  return motorcycleQuotes[Random().nextInt(motorcycleQuotes.length)];
});

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  /// The rider's first name, read once — it can't change without a re-login,
  /// and re-reading it in `build` would only re-roll the greeting below.
  late final String? _name;

  /// Picked once when the screen mounts rather than inline in `build`: this
  /// screen rebuilds on every provider tick (unread count, ride status,
  /// active bike) and a greeting that reshuffles on each of those would be
  /// visually noisy.
  late final Greeting _greeting;

  @override
  void initState() {
    super.initState();
    _name = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first;
    _greeting = greetingDetailFor(DateTime.now(), name: _name);
  }

  @override
  Widget build(BuildContext context) {
    final activeBike = ref.watch(activeBikeProvider);
    final rideState = ref.watch(rideRecordingProvider);
    final quote = ref.watch(dashboardQuoteProvider);

    // If actively recording, push to active ride screen
    if (rideState.status == RecordingStatus.active ||
        rideState.status == RecordingStatus.paused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/ride/active');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 8,
              AppDimensions.paddingMd, AppDimensions.paddingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: notifications + settings (editorial has no chrome title here)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _NotificationBellButton(unreadCount: ref.watch(unreadNotificationCountProvider)),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 1. Greeting + quote — one card, not two. The casual line
              // carries the rider's name when the picked variant has a
              // `{name}` slot ("Evening, Sam."); otherwise the name keeps its
              // own large display weight beneath the line. The quote sits
              // under both as a deliberately much smaller, muted footnote —
              // it's flavour text, so it must not compete with the greeting
              // it now shares a box with. Capped at 3 lines so an unusually
              // long one can't push the bike picker off-screen.
              EditorialCard(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_greeting.usesName)
                                Text(_greeting.line,
                                    style: display(22, height: 1.15),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)
                              else ...[
                                Text(_greeting.line,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(_name ?? 'Rider', style: display(22)),
                              ],
                            ],
                          ),
                        ),
                        if (activeBike != null && activeBike.rideCount > 0)
                          EditorialPill('${activeBike.rideCount} rides',
                              tone: PillTone.accent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${quote.$1} ${quote.$2}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: display(13,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Bike card / no-bike warning
              if (activeBike != null)
                EditorialCard(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  onTap: () => context.go('/home/garage'),
                  child: Row(
                    children: [
                      // The rider's own photo of this bike when there is one,
                      // otherwise the generic icon tile (see [BikePhoto]).
                      BikePhoto(
                        imagePath: activeBike.imagePath,
                        width: 44,
                        height: 44,
                        iconSize: 24,
                        iconColor: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeBike.displayName,
                                style: display(16, letterSpacing: 0)),
                            const SizedBox(height: 2),
                            Text('Ready to ride',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text('Change',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ],
                  ),
                )
              else
                EditorialCard(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  borderColor: AppColors.attention,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.attention),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('No active bike selected',
                            style: TextStyle(color: AppColors.textPrimary)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/home/garage/add'),
                        child: const Text('Add Bike'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // 3. Ride with friends. The widget owns the whole flow — friend
              // picker, group-ride creation, invites and navigation.
              const RideWithFriendsButton(),
              const SizedBox(height: 24),

              // 4. Start ride (slide) button. The bike's total km / ride count
              // / days-since-last-ride chips used to sit between these two —
              // they now live on the Rides tab, which is where riders go to
              // look back at what they've done. This screen is for starting.
              _SlideToStartButton(enabled: activeBike != null),
              const SizedBox(height: 10),
              Center(
                child: Text('Swipe right to start recording',
                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ),

              if (rideState.error != null) ...[
                const SizedBox(height: 16),
                EditorialCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.danger,
                  child: Text(rideState.error!,
                      style: TextStyle(color: AppColors.danger, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A "slide to start" gesture: drag anywhere on the button and the fill/
/// thumb track your finger continuously from 0% to 100% of its width.
/// Release past [_commitThreshold] (35% — kept low since gripping/dragging
/// precisely with riding gloves on is hard) and the ride starts — the fill
/// animates the rest of the way to 100% first as a "locked in" cue, you
/// don't have to physically drag all the way to the end. Release short of
/// the threshold and it snaps back to 0. The whole button is the drag
/// target (not just the thumb) — more forgiving to grab one-handed, or
/// with gloves on, than a small precise handle would be.
class _SlideToStartButton extends ConsumerStatefulWidget {
  final bool enabled;
  const _SlideToStartButton({required this.enabled});

  @override
  ConsumerState<_SlideToStartButton> createState() => _SlideToStartButtonState();
}

class _SlideToStartButtonState extends ConsumerState<_SlideToStartButton>
    with SingleTickerProviderStateMixin {
  static const double _commitThreshold = 0.35;
  static const double _trackHeight = 60;
  static const double _thumbSize = 48;

  late final AnimationController _ctrl;
  double _trackWidth = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_trackWidth <= 0) return;
    // Setting .value directly (rather than animateTo) tracks the finger
    // 1:1 with no easing lag, and implicitly stops any in-flight settle
    // animation if the user grabs it again mid-snap-back.
    _ctrl.value = (_ctrl.value + details.delta.dx / _trackWidth).clamp(0.0, 1.0);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_ctrl.value >= _commitThreshold) {
      _ctrl.animateTo(1.0, curve: Curves.easeOut).then((_) => _triggerStart());
    } else {
      _ctrl.animateTo(0.0, curve: Curves.easeOut);
    }
  }

  void _onPanCancel() => _ctrl.animateTo(0.0, curve: Curves.easeOut);

  void _triggerStart() async {
    await ref.read(rideRecordingProvider.notifier).startRide();
    if (!mounted) return;
    if (ref.read(rideRecordingProvider).status == RecordingStatus.active) {
      context.go('/ride/active');
    } else {
      // startRide() didn't actually go active (permission denied, no bike,
      // GPS disabled, ...) — don't leave the bar stuck full; let the rider
      // try again. rideState.error (rendered below this widget) explains why.
      _ctrl.animateTo(0.0, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStarting =
        ref.watch(rideRecordingProvider).status == RecordingStatus.starting;
    final enabled = widget.enabled && !isStarting;

    // The track was hard-coded to `AppColors.ink` (near-black in both
    // palettes). On Carbon Mono that's right — a black slab with a lime fill
    // reads as instrument panel against the dark background. On Editorial it
    // was the one black control on a cream page where every other action
    // (buttons, links, active borders) is the blue primary, so it looked like
    // it belonged to a different app. On the light palette the track is the
    // primary itself and the drag fill deepens to `primaryDark`, which keeps
    // the progress cue that the black/primary contrast used to provide.
    // Brightness is the palette discriminator: Editorial builds a light
    // ThemeData, Carbon Mono a dark one (see AppTheme.build).
    final isLightPalette = Theme.of(context).brightness == Brightness.light;
    final trackColor = enabled
        ? (isLightPalette ? AppColors.primary : AppColors.ink)
        : AppColors.textTertiary;
    final fillColor =
        isLightPalette ? AppColors.primaryDark : AppColors.primary;
    final thumbIconColor = enabled
        ? (isLightPalette ? AppColors.primary : AppColors.ink)
        : AppColors.textTertiary;

    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = (constraints.maxWidth - _thumbSize).clamp(1.0, double.infinity);

        return GestureDetector(
          onPanUpdate: enabled ? _onPanUpdate : null,
          onPanEnd: enabled ? _onPanEnd : null,
          onPanCancel: enabled ? _onPanCancel : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: SizedBox(
              height: _trackHeight,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final fraction = _ctrl.value;
                  return Stack(
                    children: [
                      Container(color: trackColor),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        alignment: Alignment.centerLeft,
                        child: Container(color: fillColor),
                      ),
                      Center(
                        child: isStarting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Opacity(
                                opacity: (1 - fraction * 2).clamp(0.0, 1.0),
                                child: Text('Slide to start ride',
                                    style: display(16,
                                        color: AppColors.onInk, letterSpacing: 0.2)),
                              ),
                      ),
                      Positioned(
                        left: fraction * _trackWidth,
                        top: (_trackHeight - _thumbSize) / 2,
                        child: Container(
                          width: _thumbSize,
                          height: _thumbSize,
                          decoration: BoxDecoration(
                            color: AppColors.onInk,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward,
                              color: thumbIconColor, size: 22),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  const _NotificationBellButton({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
