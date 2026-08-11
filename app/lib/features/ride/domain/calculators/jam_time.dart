/// Seconds of a completed ride spent stopped while still recording — the
/// "stuck at a light / stuck in traffic" time riders in Dhaka actually care
/// about. Not the same thing as time the ride was *paused*: pausing already
/// stops the ride clock, so paused time never reaches [durationSeconds] and
/// therefore never reaches this calculation at all. This is stopped time the
/// rider sat through while still recording.
///
/// Deliberately not a second GPS-derived measurement of its own.
/// `movingSeconds` (see average_speed.dart) already classifies every fix as
/// moving/idle at the same 1 m/s cutoff the recorder stamps onto
/// `ride_points.period_type`, so "everything that isn't moving" is just the
/// ride clock minus that number — reusing it is what keeps this number from
/// ever disagreeing with the moving-time average speed derived from the same
/// data.
///
/// Clamped to zero: a ride resumed after an app kill rebuilds its moving
/// seconds from whatever GPS fixes made it to disk (see
/// `ride_resume.dart`), which is an honest approximation, not an exact
/// complement of the separately-restored elapsed-time snapshot. Without the
/// clamp a ride like that could report a small negative jam time.
///
/// Pure so it can be tested directly; see `jam_time_test.dart`.
int jamSeconds({required int durationSeconds, required int movingSeconds}) {
  final jam = durationSeconds - movingSeconds;
  return jam > 0 ? jam : 0;
}
