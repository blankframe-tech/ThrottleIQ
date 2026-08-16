import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/services/auto_tracking_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/models/ride_model.dart';
import '../../domain/entities/ride_entity.dart';

/// Whether the rider has turned auto-tracking on, and the plumbing to change
/// it.
///
/// Off by default and never enabled implicitly. All-day motion monitoring with
/// "Always" location is a meaningful thing to ask for — it is also the harder
/// Play/App Store review conversation and a privacy-policy change — so it
/// happens exactly once, deliberately, with the rider looking at it.
final autoTrackingEnabledProvider =
    AsyncNotifierProvider<AutoTrackingNotifier, bool>(AutoTrackingNotifier.new);

class AutoTrackingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => AutoTrackingService.isEnabled();

  /// Turns auto-tracking on, collecting the permissions it needs first.
  ///
  /// Returns a human-readable reason on failure, or null on success. The
  /// permissions are requested in a deliberate order — background location
  /// first, because it is the one that can't be worked around, and there is no
  /// point asking about notifications for a feature that can't run.
  Future<String?> enable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on location services to let ThrottleIQ detect rides.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Location permission is required to detect rides.';
    }

    // "While in use" is not enough: the whole feature is about noticing a ride
    // when the app is closed. The plugin's own request flow explains the
    // upgrade better than a bare system dialog, so it is left to do the ask
    // (see AutoTrackingService's backgroundPermissionRationale) — but if the
    // rider has already refused Always outright, say so rather than silently
    // enabling something that will never fire.
    if (permission == LocationPermission.whileInUse) {
      final upgraded = await Geolocator.requestPermission();
      if (upgraded != LocationPermission.always) {
        return 'ThrottleIQ needs "Always" location access to detect rides '
            'while the app is closed. You can change this in Settings.';
      }
    }

    // Non-fatal: detection still works without notification permission, the
    // rider just won't be asked which bike a detected ride was on.
    await NotificationService.instance.requestPermissions();

    await AutoTrackingService.setEnabled(true);
    final started = await AutoTrackingService.instance.start();
    if (!started) {
      await AutoTrackingService.setEnabled(false);
      return 'Could not start background tracking on this device.';
    }

    await NotificationService.instance.scheduleDailySummary();
    state = const AsyncValue.data(true);
    return null;
  }

  Future<void> disable() async {
    await AutoTrackingService.setEnabled(false);
    await AutoTrackingService.instance.stop();
    await NotificationService.instance.cancelDailySummary();
    state = const AsyncValue.data(false);
  }
}

final rideAttributionProvider =
    Provider<RideAttribution>((ref) => RideAttribution(ref));

/// Applies the rider's answer to "which bike was this ride on?".
class RideAttribution {
  RideAttribution(this._ref);
  final Ref _ref;

  /// Confirms or corrects a ride's bike.
  ///
  /// The stats move is the part that's easy to forget and expensive to get
  /// wrong: rewriting `rides.bike_id` alone would leave the distance credited
  /// to the bike the app guessed, so history would look corrected while both
  /// bikes' maintenance intervals stayed wrong. Distance-based service
  /// reminders are a core promise of this app, so the correction has to reach
  /// them.
  ///
  /// Confirming the *same* bike the app guessed is still a confirmation: it
  /// moves nothing, but it does stop the prompt asking again.
  Future<void> confirm({
    required RideEntity ride,
    required String bikeId,
  }) async {
    if (ride.bikeId != bikeId) {
      await BikeDao().moveRideStats(
        fromBikeId: ride.bikeId,
        toBikeId: bikeId,
        distanceM: ride.distanceM,
      );
    }
    await RideDao().confirmBikeAttribution(ride.id, bikeId);
    _ref.invalidate(garageProvider);
    _ref.invalidate(unconfirmedAutoRidesProvider);
  }
}

/// Auto-detected rides still waiting for the rider to say which bike they were
/// on. Drives the confirmation prompt and the "needs review" badge.
final unconfirmedAutoRidesProvider =
    FutureProvider<List<RideEntity>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const [];
  // Rebuild whenever the garage changes: confirming a ride's bike is one of
  // the things that can change it.
  ref.watch(garageProvider);
  final rows = await RideDao().getUnconfirmedAutoRides(uid);
  return rows.map(RideModel.fromMap).toList();
});
