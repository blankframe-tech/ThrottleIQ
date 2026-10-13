/// SharedPreferences keys shared between the ride recorder (UI isolate) and
/// the background auto-tracker (task-handler isolate). Kept dependency-free so
/// the background isolate's code doesn't import the recorder's.
class RidePrefsKeys {
  RidePrefsKeys._();

  /// The recovery marker: set for exactly as long as a ride is being
  /// recorded (or sits paused after a restore). The auto-tracker reads it to
  /// stay out of a manual recording's way (§90.C3).
  static const activeRideId = 'active_ride_id';
}
