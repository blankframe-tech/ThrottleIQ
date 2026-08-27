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

/// Why [AutoTrackingNotifier.enable] didn't turn tracking on.
///
/// A typed reason, not a raw string, so the caller (which has a
/// [BuildContext]) picks the localized copy — this provider has no context to
/// read [AppLocalizations] from, and English literals here would be exactly
/// the Bangla-parity gap `arb_parity_test.dart` can't see.
enum AutoTrackingEnableFailure {
  locationServicesOff,
  permissionDenied,
  alwaysPermissionRequired,
  startFailed,
}

class AutoTrackingNotifier extends AsyncNotifier<bool> {
  /// Whether the switch should read as on.
  ///
  /// The stored flag alone isn't enough: it only records what the rider last
  /// chose *in this app*. If they later revoke "Allow all the time" from the
  /// OS Settings app — the exact permission this feature depends on — the
  /// flag stays true and the switch would keep lying about being on with no
  /// way for the rider to tell, right up until the feature silently stops
  /// detecting rides. Rebuilding re-checks the real OS permission every time
  /// (app resume — see the `ref.invalidate` in app.dart's
  /// didChangeAppLifecycleState — and whenever this screen mounts) and
  /// flips the stored flag off the moment they no longer match, so "on" here
  /// always means the feature can actually run right now.
  @override
  Future<bool> build() async {
    final storedEnabled = await AutoTrackingService.isEnabled();
    if (!storedEnabled) return false;

    final servicesOn = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final stillGranted = servicesOn && permission == LocationPermission.always;
    if (stillGranted) return true;

    await AutoTrackingService.setEnabled(false);
    await AutoTrackingService.instance.stop();
    return false;
  }

  /// Turns auto-tracking on, collecting the permissions it needs first.
  ///
  /// Returns the failure reason, or null on success. The permissions are
  /// requested in a deliberate order — background location first, because it
  /// is the one that can't be worked around, and there is no point asking
  /// about notifications for a feature that can't run.
  Future<AutoTrackingEnableFailure?> enable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return AutoTrackingEnableFailure.locationServicesOff;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return AutoTrackingEnableFailure.permissionDenied;
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
        return AutoTrackingEnableFailure.alwaysPermissionRequired;
      }
    }

    // Non-fatal: detection still works without notification permission, the
    // rider just won't be asked which bike a detected ride was on.
    await NotificationService.instance.requestPermissions();

    await AutoTrackingService.setEnabled(true);
    final started = await AutoTrackingService.instance.start();
    if (!started) {
      await AutoTrackingService.setEnabled(false);
      return AutoTrackingEnableFailure.startFailed;
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

/// The rider's chosen active-hours window for auto-tracking — whether it's
/// restricted to a daily window at all, and if so, which one.
class AutoTrackingSchedule {
  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  const AutoTrackingSchedule({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
  });
}

/// Loads and edits [AutoTrackingSchedule]. Separate from
/// [autoTrackingEnabledProvider] because the window is meaningful to look at
/// and change independently of whether tracking is currently on — a rider
/// picking their commute hours before ever flipping the main switch on
/// shouldn't be blocked from doing so.
final autoTrackingScheduleProvider = AsyncNotifierProvider<
    AutoTrackingScheduleNotifier, AutoTrackingSchedule>(
  AutoTrackingScheduleNotifier.new,
);

class AutoTrackingScheduleNotifier extends AsyncNotifier<AutoTrackingSchedule> {
  @override
  Future<AutoTrackingSchedule> build() async {
    final enabled = await AutoTrackingService.isScheduleEnabled();
    final (start, end) = await AutoTrackingService.getScheduleWindow();
    return AutoTrackingSchedule(
        enabled: enabled, startMinutes: start, endMinutes: end);
  }

  Future<void> setEnabled(bool value) async {
    await AutoTrackingService.setScheduleEnabled(value);
    await AutoTrackingService.instance.applyScheduleChange();
    state = AsyncValue.data(AutoTrackingSchedule(
      enabled: value,
      startMinutes: state.requireValue.startMinutes,
      endMinutes: state.requireValue.endMinutes,
    ));
  }

  /// [startMinutes] must be strictly before [endMinutes] — the UI's time
  /// pickers enforce this and disable the save action otherwise, since this
  /// single-window model doesn't support a range that wraps past midnight.
  Future<void> setWindow(int startMinutes, int endMinutes) async {
    await AutoTrackingService.setScheduleWindow(startMinutes, endMinutes);
    await AutoTrackingService.instance.applyScheduleChange();
    state = AsyncValue.data(AutoTrackingSchedule(
      enabled: state.requireValue.enabled,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    ));
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
