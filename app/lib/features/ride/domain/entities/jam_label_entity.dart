/// Why a rider-labelled jam window closed.
enum JamLabelEndReason {
  /// The rider tapped "Jam released" — the only reason that is real ground
  /// truth for the jam's end.
  released,

  /// The ride was paused while the label was open. Pausing stops the ride
  /// clock, so the window is cut there rather than left spanning the pause.
  paused,

  /// The ride ended (saved or discarded) while the label was open.
  rideEnded,
}

/// One snapshot of the recorder at the moment the rider tapped a jam button.
///
/// `elapsedSeconds`/`movingSeconds` are the ride clock and the recorder's
/// moving-time counter at that instant — the same two numbers jam_time.dart
/// subtracts — so the difference between two snapshots is exactly what the
/// app's own GPS-derived jam detection credited inside the labelled window.
class JamLabelMark {
  final DateTime at;
  final int elapsedSeconds;
  final int movingSeconds;
  final double distanceM;
  final double speedMs;
  final double? lat;
  final double? lng;

  const JamLabelMark({
    required this.at,
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.distanceM,
    required this.speedMs,
    this.lat,
    this.lng,
  });

  int get stoppedSeconds {
    final s = elapsedSeconds - movingSeconds;
    return s > 0 ? s : 0;
  }

  Map<String, dynamic> toMap() => {
        'at': at.toUtc().toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'movingSeconds': movingSeconds,
        'distanceM': distanceM,
        'speedMs': speedMs,
        'lat': lat,
        'lng': lng,
      };
}

/// A rider-labelled jam: "I'm in a jam" → "Jam released", recorded by
/// internal beta testers (see beta_testers.dart) as ground truth to tune the
/// automatic jam detection against. Never shown back to the rider as a stat.
class JamLabel {
  final String id;
  final String rideId;
  final JamLabelMark start;
  final JamLabelMark? end;
  final JamLabelEndReason? endReason;

  const JamLabel({
    required this.id,
    required this.rideId,
    required this.start,
    this.end,
    this.endReason,
  });

  bool get isOpen => end == null;

  JamLabel close(JamLabelMark mark, JamLabelEndReason reason) =>
      JamLabel(id: id, rideId: rideId, start: start, end: mark, endReason: reason);

  /// Wall-clock length of the window the rider labelled.
  int? get labelledSeconds => end?.at.difference(start.at).inSeconds;

  /// Ride-clock seconds inside the window (excludes nothing today, since a
  /// pause closes the label — kept separate from [labelledSeconds] so an
  /// app kill/restore mid-jam shows up as a mismatch instead of hiding).
  int? get rideClockSeconds =>
      end == null ? null : end!.elapsedSeconds - start.elapsedSeconds;

  /// What the automatic jam detection counted as stopped inside the window.
  /// Compare against [labelledSeconds] to see how much of a real jam the
  /// algorithm misses (crawling counted as moving) or over-counts.
  int? get detectedStoppedSeconds {
    if (end == null) return null;
    final d = end!.stoppedSeconds - start.stoppedSeconds;
    return d > 0 ? d : 0;
  }

  /// Metres crept forward during the jam.
  double? get distanceDuringM =>
      end == null ? null : end!.distanceM - start.distanceM;

  Map<String, dynamic> toMap() => {
        'id': id,
        'rideId': rideId,
        'start': start.toMap(),
        'end': end?.toMap(),
        'endReason': endReason?.name,
        'labelledSeconds': labelledSeconds,
        'rideClockSeconds': rideClockSeconds,
        'detectedStoppedSeconds': detectedStoppedSeconds,
        'distanceDuringM': distanceDuringM,
        // Bump if the shape or the meaning of a field changes, so analysis
        // can tell old labels apart.
        'schema': 1,
      };
}
