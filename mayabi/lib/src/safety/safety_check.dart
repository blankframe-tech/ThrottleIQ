import 'dart:async';

import '../ride/ride_recorder.dart';

/// The "Are you OK?" step between a detected event and an alert.
///
/// Crash and unusual-stop detection will have false alarms (a dropped
/// phone, a Dhaka jam), so an event only ever *asks* the rider first. If she
/// doesn't answer within [countdown], [onEscalate] fires; that is where the
/// app sends `ThrottleIqClient.sendAlert` to Maya ops. A manual SOS tap
/// skips the countdown via [riderNeedsHelp].
///
/// Wire it as: `RideRecorder(onSafetyEvent: check.raise)`; show a
/// full-screen prompt while [pending] is non-null, with a big "I'm OK"
/// ([riderIsOk]) and "Get help" ([riderNeedsHelp]).
class SafetyCheck {
  SafetyCheck({
    required this.onEscalate,
    this.countdown = const Duration(seconds: 60),
    this.onChanged,
    Timer Function(Duration, void Function())? timer,
  }) : _timer = timer ?? Timer.new;

  final Duration countdown;

  /// Called once per unanswered (or "Get help") event.
  final void Function(SafetyEvent event) onEscalate;

  /// Called whenever [pending] changes, to rebuild the prompt.
  final void Function()? onChanged;

  final Timer Function(Duration, void Function()) _timer;
  Timer? _running;
  SafetyEvent? _pending;

  /// The event the rider is being asked about, or null.
  SafetyEvent? get pending => _pending;

  /// Starts the countdown. While one is already running, a second event is
  /// folded into it (the rider is being asked already).
  void raise(SafetyEvent event) {
    if (_pending != null) return;
    _pending = event;
    _running = _timer(countdown, _escalate);
    onChanged?.call();
  }

  /// "I'm OK": the event is dropped, nothing is sent.
  void riderIsOk() {
    _running?.cancel();
    _running = null;
    if (_pending == null) return;
    _pending = null;
    onChanged?.call();
  }

  /// "Get help" on the prompt: escalate now.
  void riderNeedsHelp() => _escalate();

  void _escalate() {
    _running?.cancel();
    _running = null;
    final e = _pending;
    if (e == null) return;
    _pending = null;
    onChanged?.call();
    onEscalate(e);
  }

  void dispose() {
    _running?.cancel();
    _running = null;
    _pending = null;
  }
}
