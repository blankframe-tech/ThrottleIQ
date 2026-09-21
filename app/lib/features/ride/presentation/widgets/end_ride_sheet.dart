import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';

/// What the rider chose in [showEndRideSheet]. A `null` result from the sheet
/// means "keep riding" (button, scrim tap, or back gesture).
class EndRideChoice {
  /// Open the share screen after the ride is saved instead of the summary.
  final bool share;
  const EndRideChoice({required this.share});
}

/// The end-ride confirmation, sized for a gloved thumb on a moving bike.
///
/// Replaced a stock `AlertDialog` whose Cancel and "Share ride" checkbox were
/// ~40 dp targets tucked beside each other (grill §3.1.1). Every
/// control here is full width and at least 56 dp tall, and ending the ride is
/// a 1.2 s press-and-hold rather than a tap, so a bump or a mis-aimed thumb
/// can't save a ride the rider meant to keep recording.
Future<EndRideChoice?> showEndRideSheet(BuildContext context) {
  return showModalBottomSheet<EndRideChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    // Dragging the sheet would compete with the hold gesture's pointer; the
    // scrim tap and "Keep riding" are the ways out.
    enableDrag: false,
    showDragHandle: false,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
    ),
    builder: (_) => const EndRideSheet(),
  );
}

class EndRideSheet extends StatefulWidget {
  const EndRideSheet({super.key});

  @override
  State<EndRideSheet> createState() => _EndRideSheetState();
}

class _EndRideSheetState extends State<EndRideSheet> {
  bool _share = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('End ride?', style: display(22, letterSpacing: 0)),
            const SizedBox(height: 4),
            Text('Your ride will be saved.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            // Whole row is the target, not just the switch.
            Material(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: InkWell(
                key: const Key('endRideShareToggle'),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                onTap: () => setState(() => _share = !_share),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.ios_share, color: AppColors.textPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Share ride after saving',
                              style: TextStyle(
                                  fontSize: 16, color: AppColors.textPrimary)),
                        ),
                        // Excluded so the row's InkWell is the only target —
                        // the switch just mirrors state.
                        ExcludeSemantics(
                          child: IgnorePointer(
                            child: Switch(
                              value: _share,
                              activeTrackColor: AppColors.primary,
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            HoldToEndButton(
              onConfirmed: () =>
                  Navigator.of(context).pop(EndRideChoice(share: _share)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: const Text('Keep riding'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width 72 dp press-and-hold button. A ring around the stop icon fills
/// over [holdDuration] with a light haptic tick at each quarter; letting go
/// early unwinds it. Same pointer-level mechanics as `HoldToStartButton` —
/// see that widget for why this is a [Listener] rather than a
/// `GestureDetector`.
///
/// No haptic on completion: [onConfirmed] leads to
/// `RideRecordingNotifier.stopRide`, which fires `HapticService.rideStop()`.
class HoldToEndButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final Duration holdDuration;

  const HoldToEndButton({
    super.key,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<HoldToEndButton> createState() => _HoldToEndButtonState();
}

class _HoldToEndButtonState extends State<HoldToEndButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _fired = false;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
      reverseDuration: widget.holdDuration * 0.4,
    )
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
  }

  void _onTick() {
    // Quarter ticks on the way up only; an unwinding ring stays quiet.
    if (_ctrl.status != AnimationStatus.forward) return;
    final quarter = (_ctrl.value * 4).floor();
    if (quarter > _lastTick && quarter < 4) {
      _lastTick = quarter;
      HapticFeedback.selectionClick();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _fired) return;
    _fired = true;
    widget.onConfirmed();
  }

  void _press() {
    if (_fired) return;
    _lastTick = 0;
    _ctrl.forward();
  }

  void _release() {
    if (_ctrl.status == AnimationStatus.completed) return;
    // Unconditional: a release in the same frame as the press leaves the
    // value at 0 with the controller still running forward, and a
    // `value > 0` guard would let that quick tap complete the hold.
    _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same foreground the theme gives every filled button (white on light
    // skins, surface on dark ones, ink on Retro), so this reads as the old
    // End Ride button rather than a new color pairing.
    final fg = Theme.of(context)
            .elevatedButtonTheme
            .style
            ?.foregroundColor
            ?.resolve(const <WidgetState>{}) ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.surface
            : Colors.white);
    return Semantics(
      button: true,
      label: 'End ride. Press and hold.',
      // A hold is invisible to TalkBack/VoiceOver; their double-tap confirms.
      onTap: _fired
          ? null
          : () {
              _fired = true;
              widget.onConfirmed();
            },
      child: Listener(
        key: const Key('holdToEndButton'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            return Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: t,
                          strokeWidth: 4,
                          color: fg,
                          backgroundColor: fg.withValues(alpha: 0.3),
                        ),
                        Icon(Icons.stop_rounded, color: fg, size: 24),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: ExcludeSemantics(
                      child: Text(
                        t > 0 ? 'Keep holding…' : 'Hold to end ride',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: fg),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
