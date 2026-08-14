import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/editorial.dart';

/// Circular press-and-hold start control — the rounded skins' counterpart to
/// the Record screen's slide-to-start track (see [StartControlStyle]).
///
/// Hold anywhere on the ring and a progress arc sweeps clockwise from the top
/// over [holdDuration]; complete it and [onStart] fires. Release early and the
/// arc unwinds — faster than it filled, so an abandoned press feels dismissed
/// rather than merely rewound.
///
/// Why hold-to-start rather than a plain tap: starting a ride spins up GPS,
/// sensors and a wakelock, and this button sits under the thumb on the screen
/// a rider opens most. It is the same reasoning that made the original control
/// a slide — an accidental brush must not start recording. The three cues
/// (arc, swelling glow, label) all track one animation value, so there is
/// never a frame where the ring says one thing and the label another.
///
/// Deliberately no haptic on completion here: [onStart] leads to
/// `RideRecordingNotifier.startRide`, which already fires
/// `HapticService.rideStart()`. Buzzing twice for one action reads as a bug.
class HoldToStartButton extends StatefulWidget {
  /// Called once the hold completes. Starting is the caller's job — this
  /// widget only owns the gesture.
  final VoidCallback onStart;

  /// False greys the control out and ignores touches (no bike selected).
  final bool enabled;

  /// True while a start is in flight — swaps the label for a spinner and locks
  /// the ring full, so the rider can't queue a second start.
  final bool busy;

  /// How long the rider must hold. 900 ms is the window that tested as
  /// "deliberate but not annoying": long enough that a pocket-brush or a
  /// stumble against the screen can't complete it, short enough that it never
  /// feels like the app is making you wait.
  final Duration holdDuration;

  final double size;

  const HoldToStartButton({
    super.key,
    required this.onStart,
    this.enabled = true,
    this.busy = false,
    this.holdDuration = const Duration(milliseconds: 900),
    this.size = 168,
  });

  @override
  State<HoldToStartButton> createState() => _HoldToStartButtonState();
}

class _HoldToStartButtonState extends State<HoldToStartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Guards against firing twice: the controller can report completion while a
  /// pointer-up for the same gesture is still in flight.
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
      // Unwinds at ~2.5x the fill speed, so letting go reads as the control
      // dismissing the attempt rather than politely rewinding it.
      reverseDuration: widget.holdDuration * 0.4,
    )..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant HoldToStartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.holdDuration != oldWidget.holdDuration) {
      _ctrl.duration = widget.holdDuration;
      _ctrl.reverseDuration = widget.holdDuration * 0.4;
    }
    // A start that failed (permission denied, GPS off) comes back as
    // busy: false with the ring still full. Unwind it so the rider gets an
    // obviously re-armed control rather than one stuck at 100%.
    if (oldWidget.busy && !widget.busy) _reset();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _fired) return;
    _fired = true;
    widget.onStart();
  }

  void _onPressStart() {
    if (!widget.enabled || widget.busy) return;
    _fired = false;
    _ctrl.forward();
  }

  /// Unwinds the arc when the rider lets go short of the end.
  ///
  /// A completed hold is left alone: it has already fired [onStart], and
  /// rewinding it would animate the ring back to empty underneath the spinner
  /// that is about to replace it.
  void _release() {
    if (_ctrl.status == AnimationStatus.completed) return;
    if (_ctrl.value > 0) _ctrl.reverse();
  }

  void _reset() {
    _fired = false;
    _ctrl.value = 0;
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.busy;
    final isLightPalette = Theme.of(context).brightness == Brightness.light;

    // Mirrors _SlideToStartButton's palette logic so the two controls read as
    // the same button in different clothes: on a light skin the face is the
    // primary (the color every other action already uses), on a dark one it's
    // the near-black instrument-panel ink with a lime arc.
    final faceColor = enabled
        ? (isLightPalette ? AppColors.primary : AppColors.ink)
        : AppColors.textTertiary;
    final arcColor = isLightPalette ? AppColors.primaryDark : AppColors.primary;

    return Semantics(
      button: true,
      enabled: enabled,
      // Spelled out for screen readers: a hold gesture is invisible to
      // TalkBack/VoiceOver, and "start ride" alone would suggest a tap.
      label: 'Start ride. Press and hold.',
      onTap: enabled ? widget.onStart : null,
      // Listener, not GestureDetector: a tap recognizer doesn't report the
      // press until it wins the gesture arena, which for a lone tap means
      // after kPressTimeout (100 ms). For a hold control that delay is visible
      // — the ring would sit dead for a tenth of a second after the finger
      // lands — and it makes the gesture's start depend on arena timing rather
      // than on the pointer. Raw pointer events start the arc on contact.
      // Nothing here scrolls, so there is no competing recognizer to yield to.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _onPressStart(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              return CustomPaint(
                painter: _HoldRingPainter(
                  progress: t,
                  faceColor: faceColor,
                  arcColor: arcColor,
                  trackColor: AppColors.textTertiary.withValues(alpha: 0.25),
                ),
                child: Center(
                  child: widget.busy
                      ? SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onInk,
                          ),
                        )
                      : _Label(progress: t, enabled: enabled),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "HOLD" → "GO" at the point the arc is far enough round that the rider has
/// clearly committed. Crossfaded rather than swapped so the change registers
/// as the same label transforming.
class _Label extends StatelessWidget {
  final double progress;
  final bool enabled;

  const _Label({required this.progress, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final committed = progress > 0.6;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: Column(
        key: ValueKey(committed),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            committed ? Icons.play_arrow_rounded : Icons.two_wheeler,
            size: committed ? 34 : 28,
            color: AppColors.onInk,
          ),
          const SizedBox(height: 4),
          Text(
            committed ? 'GO' : 'HOLD',
            style: display(committed ? 20 : 16,
                color: AppColors.onInk, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Paints the filled face, its progress arc, and the glow that swells as the
/// hold advances.
class _HoldRingPainter extends CustomPainter {
  final double progress;
  final Color faceColor;
  final Color arcColor;
  final Color trackColor;

  _HoldRingPainter({
    required this.progress,
    required this.faceColor,
    required this.arcColor,
    required this.trackColor,
  });

  static const double _strokeWidth = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // The arc is stroked ON the ring's radius, so the circle it sweeps has to
    // be inset by half the stroke or it clips against the widget's bounds.
    final radius = (size.shortestSide - _strokeWidth) / 2;

    // Glow first, underneath everything: it reads as light coming off the
    // button rather than a ring drawn around it. Scales with progress so the
    // control visibly "charges" as it's held.
    if (progress > 0) {
      canvas.drawCircle(
        center,
        radius * (1 + 0.06 * progress),
        Paint()
          ..color = arcColor.withValues(alpha: 0.18 * progress)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + 16 * progress),
      );
    }

    // The face. Shrinks very slightly under the finger — the standard
    // "pressed" cue, done in paint rather than with a Transform so it can't
    // desync from the arc.
    canvas.drawCircle(
      center,
      (radius - _strokeWidth / 2) * (1 - 0.02 * progress),
      Paint()..color = faceColor,
    );

    // Unfilled track, so the gesture's full extent is visible before it starts.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = trackColor,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      // -pi/2 starts the sweep at 12 o'clock; a progress arc that began at 3
      // o'clock would read as a loading spinner rather than as filling up.
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = arcColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HoldRingPainter old) =>
      old.progress != progress ||
      old.faceColor != faceColor ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}
