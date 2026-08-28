import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/bike_colors.dart';
import '../../../../core/constants/motorcycle_quotes.dart';
import '../../../../core/theme/app_shape_profile.dart';
import '../../../../core/utils/greetings.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../social/presentation/widgets/ride_mode_selector.dart';
import '../providers/ride_recording_provider.dart';
import '../widgets/bike_picker_card.dart';
import '../widgets/hold_to_start_button.dart';
import '../widgets/rider_stat_strip.dart';

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
    final accent = activeBike != null && bikeHasPhoto(activeBike)
        ? bikeAccentColor(activeBike)
        : null;

    // If actively recording, push to active ride screen
    if (rideState.status == RecordingStatus.active ||
        rideState.status == RecordingStatus.paused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/ride/active');
      });
    }

    // The screen reads top-to-bottom as one instrument panel: what you're
    // riding, what you've done on it, who you're riding with, and the throttle
    // at the bottom under your thumb. It used to be four cards of roughly
    // equal weight stacked in a scroll view, which gave the greeting the same
    // visual authority as the control that actually starts a ride.
    //
    // The throttle is deliberately *outside* the scroll view rather than the
    // last item in it: slide-to-start is the one control this screen exists
    // for, and it must be under the thumb at a fixed place every time —
    // never scrolled off, and never in a different spot depending on whether
    // an error card happens to be showing above it.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        // A faint wash of the active bike's own color, so the screen you
        // start a ride from reads as *that bike's* dashboard rather than a
        // neutral shell that happens to show its name. Subtle on purpose —
        // this sits behind body text, so it stays low-alpha and fades into
        // the ordinary background well before the fold.
        decoration: BoxDecoration(
          gradient: accent != null
              ? RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.3,
                  colors: [
                    accent.withValues(alpha: 0.18),
                    AppColors.background,
                  ],
                  stops: const [0, 0.65],
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      AppDimensions.paddingMd, 4, AppDimensions.paddingMd, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Settings and Notifications used to live here as icon
                      // buttons; both moved to the Profile tab's header, next to
                      // the rest of the account-level chrome (see
                      // GarageScreen) — this screen has no title bar of its
                      // own, and the hero below is the header.
                      const SizedBox(height: 4),

                      // 1. Hero — the bike, at full width, wearing the greeting.
                      // The casual line carries the rider's name when the picked
                      // variant has a `{name}` slot ("Evening, Sam."); otherwise
                      // it sits above the name as an overline.
                      if (activeBike != null)
                        BikePickerCard(
                          activeBike: activeBike,
                          overlineText:
                              _greeting.usesName ? null : _greeting.line,
                          titleText: _greeting.usesName
                              ? _greeting.line
                              : (_name ?? 'Rider'),
                          accentColor: accent,
                        )
                      else
                        const _NoBikeCard(),
                      const SizedBox(height: 18),

                      // 2. What you've done so far — the reason to go again.
                      const RiderStatStrip(),
                      const SizedBox(height: 22),

                      // 3. Solo/Group choice. The widget owns the whole flow —
                      // friend picker or join-by-code, group-ride creation,
                      // invites, navigation.
                      const RideModeSelector(),

                      if (rideState.error != null) ...[
                        const SizedBox(height: 16),
                        EditorialCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: AppColors.danger,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(rideState.error!,
                                  style: TextStyle(
                                      color: AppColors.danger, fontSize: 13),
                                  textAlign: TextAlign.center),
                              if (rideState.blockKind !=
                                  RecordingBlockKind.none) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => rideState.blockKind ==
                                          RecordingBlockKind.locationServicesOff
                                      ? Geolocator.openLocationSettings()
                                      : Geolocator.openAppSettings(),
                                  child: Text(
                                    rideState.blockKind ==
                                            RecordingBlockKind
                                                .locationServicesOff
                                        ? 'Turn on Location'
                                        : 'Open App Settings',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 4. Start ride, pinned.
              Padding(
                padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 8,
                    AppDimensions.paddingMd, AppDimensions.paddingMd),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Which control depends on the active skin's shape profile:
                    // a slide track on the boxy/terminal skins, a press-and-hold
                    // ring on the rounded ones. See StartControlStyle for why
                    // this is the one place a skin swaps a widget rather than
                    // just restyling it.
                    if (AppDimensions.shape.startControl ==
                        StartControlStyle.holdRing)
                      _HoldToStartControl(enabled: activeBike != null)
                    else
                      _SlideToStartButton(enabled: activeBike != null),
                    const SizedBox(height: 12),
                    // Flavour text, demoted to a footer. It takes the line the
                    // "swipe right to start" hint used to own — the bar labels
                    // its own gesture, so the hint was saying it twice.
                    Text(
                      '${quote.$1} ${quote.$2}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textTertiary),
                    ),
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

/// Stands in for the hero when the rider has no bike yet — same footprint, so
/// the screen doesn't reflow the moment they add one.
class _NoBikeCard extends StatelessWidget {
  const _NoBikeCard();

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      borderColor: AppColors.attention,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.two_wheeler, size: 40, color: AppColors.attention),
          const SizedBox(height: 12),
          Text('No bike yet', style: display(22)),
          const SizedBox(height: 4),
          Text(
            'Add the bike you ride and ThrottleIQ can start tracking it.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/home/profile/add'),
            child: const Text('Add a bike'),
          ),
        ],
      ),
    );
  }
}

/// Puts the blocked-recording reason (GPS off / no permission) in front of
/// the rider immediately, as a SnackBar with a one-tap fix — the persistent
/// card above the start control says the same thing, but it can sit below
/// the fold behind the hero/stat-strip/friends cards, so a rider who just
/// slid the bar and got nothing back would otherwise have to scroll up to
/// find out why.
void _showBlockedSnackBar(BuildContext context, RideRecordingState state) {
  if (state.error == null) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(state.error!),
    duration: const Duration(seconds: 6),
    action: switch (state.blockKind) {
      RecordingBlockKind.locationServicesOff => SnackBarAction(
          label: 'TURN ON',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      RecordingBlockKind.permissionDenied => SnackBarAction(
          label: 'SETTINGS',
          onPressed: () => Geolocator.openAppSettings(),
        ),
      RecordingBlockKind.none => null,
    },
  ));
}

/// Riverpod wrapper around [HoldToStartButton] — the rounded skins' start
/// control. Owns exactly the same start/navigate/recover-from-failure flow as
/// [_SlideToStartButtonState._triggerStart], so the two controls behave
/// identically once the gesture completes; only the gesture differs.
class _HoldToStartControl extends ConsumerWidget {
  final bool enabled;
  const _HoldToStartControl({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(rideRecordingProvider).status;

    return HoldToStartButton(
      enabled: enabled,
      busy: status == RecordingStatus.starting,
      onStart: () async {
        await ref.read(rideRecordingProvider.notifier).startRide();
        if (!context.mounted) return;
        final result = ref.read(rideRecordingProvider);
        // Same recovery contract as the slide control: only navigate if the
        // ride actually went active. If it didn't, the button re-arms itself
        // (HoldToStartButton unwinds when `busy` drops back to false) and the
        // error card above explains why — echoed as a SnackBar too, since the
        // card can be scrolled out of view.
        if (result.status == RecordingStatus.active) {
          context.go('/ride/active');
        } else {
          _showBlockedSnackBar(context, result);
        }
      },
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
  ConsumerState<_SlideToStartButton> createState() =>
      _SlideToStartButtonState();
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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_trackWidth <= 0) return;
    // Setting .value directly (rather than animateTo) tracks the finger
    // 1:1 with no easing lag, and implicitly stops any in-flight settle
    // animation if the user grabs it again mid-snap-back.
    _ctrl.value =
        (_ctrl.value + details.delta.dx / _trackWidth).clamp(0.0, 1.0);
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
    final result = ref.read(rideRecordingProvider);
    if (result.status == RecordingStatus.active) {
      context.go('/ride/active');
    } else {
      // startRide() didn't actually go active (permission denied, no bike,
      // GPS disabled, ...) — don't leave the bar stuck full; let the rider
      // try again. rideState.error (rendered below this widget) explains why,
      // echoed as a SnackBar since that card can be scrolled out of view.
      _ctrl.animateTo(0.0, curve: Curves.easeOut);
      _showBlockedSnackBar(context, result);
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
        _trackWidth =
            (constraints.maxWidth - _thumbSize).clamp(1.0, double.infinity);

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
                                        color: AppColors.onInk,
                                        letterSpacing: 0.2)),
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
