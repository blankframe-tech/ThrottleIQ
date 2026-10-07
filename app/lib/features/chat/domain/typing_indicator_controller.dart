import 'dart:async';

/// Re-send `typing: true` at most this often while the rider keeps typing,
/// which also keeps `ts` inside the reader's 6 s expiry.
const Duration kTypingRefreshEvery = Duration(seconds: 3);

/// After this long with no keystroke, send `typing: false`.
const Duration kTypingIdleAfter = Duration(seconds: 4);

/// Turns keystrokes into a small number of typing-state writes.
///
/// Without it, every character would be a write — this sends `true` once,
/// refreshes it every [refreshEvery] while typing continues, and sends
/// `false` after [idleAfter] of silence, when the field is cleared, when the
/// message is sent, or on dispose. Clock and timers are injected so tests
/// can drive time.
class TypingIndicatorController {
  TypingIndicatorController({
    required this.send,
    this.refreshEvery = kTypingRefreshEvery,
    this.idleAfter = kTypingIdleAfter,
    DateTime Function()? clock,
    Timer Function(Duration, void Function())? timerFactory,
  })  : _clock = clock ?? DateTime.now,
        _timerFactory = timerFactory ?? Timer.new;

  final void Function(bool typing) send;
  final Duration refreshEvery;
  final Duration idleAfter;
  final DateTime Function() _clock;
  final Timer Function(Duration, void Function()) _timerFactory;

  bool _typing = false;
  DateTime? _lastSentAt;
  Timer? _idle;
  bool _disposed = false;

  bool get isTyping => _typing;

  void onTextChanged(String text) {
    if (_disposed) return;
    if (text.trim().isEmpty) {
      _stop();
      return;
    }
    final now = _clock();
    final last = _lastSentAt;
    if (!_typing || last == null || now.difference(last) >= refreshEvery) {
      _typing = true;
      _lastSentAt = now;
      send(true);
    }
    _idle?.cancel();
    _idle = _timerFactory(idleAfter, _stop);
  }

  /// The message went out — the rider is no longer composing it.
  void onSent() => _stop();

  void _stop() {
    _idle?.cancel();
    _idle = null;
    if (!_typing) return;
    _typing = false;
    _lastSentAt = null;
    send(false);
  }

  void dispose() {
    _stop();
    _disposed = true;
  }
}
