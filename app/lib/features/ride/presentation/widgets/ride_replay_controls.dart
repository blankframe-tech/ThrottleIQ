import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';

/// Play/pause and a scrubber that walk [position] through a finished ride's
/// local track points; the summary map draws a marker at that index.
///
/// Per-point lean isn't stored (only the ride's max), so the readout is speed.
class RideReplayControls extends StatefulWidget {
  /// One entry per track point, m/s.
  final List<double> speedsMs;

  /// Index of the replayed point; null until the rider starts a replay.
  final ValueNotifier<int?> position;

  const RideReplayControls({
    super.key,
    required this.speedsMs,
    required this.position,
  });

  /// A whole replay takes about this long, whatever the track length.
  static const replayDuration = Duration(seconds: 20);
  static const tick = Duration(milliseconds: 50);

  @override
  State<RideReplayControls> createState() => _RideReplayControlsState();
}

class _RideReplayControlsState extends State<RideReplayControls> {
  Timer? _timer;

  int get _last => widget.speedsMs.length - 1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    final start = widget.position.value;
    if (start == null || start >= _last) widget.position.value = 0;
    final ticks = RideReplayControls.replayDuration.inMilliseconds ~/
        RideReplayControls.tick.inMilliseconds;
    final step = (_last / ticks).ceil().clamp(1, _last);
    _timer = Timer.periodic(RideReplayControls.tick, (_) {
      final next = (widget.position.value ?? 0) + step;
      if (next >= _last) {
        widget.position.value = _last;
        _pause();
      } else {
        widget.position.value = next;
      }
    });
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playing = _timer != null;
    final l10n = context.l10n;
    return ValueListenableBuilder<int?>(
      valueListenable: widget.position,
      builder: (context, index, _) {
        final i = (index ?? 0).clamp(0, _last);
        return Row(
          children: [
            IconButton(
              key: const Key('ride_replay_play_pause'),
              tooltip: playing ? l10n.rideReplayPause : l10n.rideReplayPlay,
              color: context.palette.primary,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: playing ? _pause : _play,
            ),
            Expanded(
              child: Slider(
                key: const Key('ride_replay_scrubber'),
                value: i.toDouble(),
                max: _last.toDouble(),
                semanticFormatterCallback: (_) =>
                    SpeedFormatter.fromMs(widget.speedsMs[i]),
                onChanged: (v) {
                  _pause();
                  widget.position.value = v.round();
                },
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                SpeedFormatter.fromMs(widget.speedsMs[i]),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
