import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/motorcycle_quotes.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../social/presentation/providers/notification_providers.dart';
import '../providers/ride_recording_provider.dart';

/// Picked once per app session (Riverpod `Provider`s are computed lazily and
/// cached for the container's lifetime, so this stays fixed across rebuilds
/// within one app open — e.g. RecordScreen re-rendering while a ride's
/// speed/distance update — but is different again next cold start) rather
/// than "Your ride, smarter." always being the same line.
final dashboardQuoteProvider = Provider<(String, String)>((ref) {
  return motorcycleQuotes[Random().nextInt(motorcycleQuotes.length)];
});

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBike = ref.watch(activeBikeProvider);
    final rideState = ref.watch(rideRecordingProvider);
    final name = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first;
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

              // Black hero panel
              InkPanel(
                padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.onInk, width: 2),
                      ),
                      child: const Icon(Icons.speed, color: AppColors.onInk, size: 34),
                    ),
                    const SizedBox(height: 24),
                    Text(quote.$1,
                        textAlign: TextAlign.center,
                        style: display(30, color: AppColors.onInk, height: 1.1)),
                    Text(quote.$2,
                        textAlign: TextAlign.center,
                        style: display(30, color: AppColors.onInk, height: 1.1)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Greeting card
              EditorialCard(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(),
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(name ?? 'Rider', style: display(22)),
                        ],
                      ),
                    ),
                    if (activeBike != null && activeBike.rideCount > 0)
                      EditorialPill('${activeBike.rideCount} rides',
                          tone: PillTone.accent),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bike card / no-bike warning
              if (activeBike != null)
                EditorialCard(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  onTap: () => context.go('/home/garage'),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: const Icon(Icons.two_wheeler,
                            color: AppColors.textPrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeBike.displayName,
                                style: display(16, letterSpacing: 0)),
                            const SizedBox(height: 2),
                            const Text('Ready to ride',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Text('Change',
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
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.attention),
                      const SizedBox(width: 12),
                      const Expanded(
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

              // Stat chips
              if (activeBike != null)
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        value: SpeedFormatter.distanceKm(activeBike.totalDistanceM),
                        label: 'total km',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        value: '${activeBike.rideCount}',
                        label: 'rides',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        value: activeBike.lastRideAt != null
                            ? '${DateTime.now().difference(activeBike.lastRideAt!).inDays}d'
                            : '—',
                        label: 'last ride',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Start ride (slide) button
              _SlideToStartButton(enabled: activeBike != null),
              const SizedBox(height: 10),
              const Center(
                child: Text('Swipe right to start recording',
                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ),

              if (rideState.error != null) ...[
                const SizedBox(height: 16),
                EditorialCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.danger,
                  child: Text(rideState.error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
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

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: display(20)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// A "slide to start" gesture: drag anywhere on the button and the fill/
/// thumb track your finger continuously from 0% to 100% of its width.
/// Release past [_commitThreshold] (60%) and the ride starts — the fill
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
  static const double _commitThreshold = 0.6;
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
                      Container(color: enabled ? AppColors.ink : AppColors.textTertiary),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        alignment: Alignment.centerLeft,
                        child: Container(color: AppColors.primary),
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
                          decoration: const BoxDecoration(
                            color: AppColors.onInk,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward,
                              color: enabled ? AppColors.ink : AppColors.textTertiary,
                              size: 22),
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
