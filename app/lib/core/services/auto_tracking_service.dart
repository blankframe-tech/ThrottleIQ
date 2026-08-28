import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart'
    as ar;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/daos/auto_detection_dao.dart';

const _serviceId = 1000;
const _channelId = 'auto_tracking';

/// Entry point for the foreground-service isolate.
///
/// **Must be a top-level function annotated `@pragma('vm:entry-point')`** —
/// the tree-shaker has no way to see that the platform side calls this, and
/// without the annotation it is removed from release builds, producing an
/// auto-tracker that works perfectly in debug and never fires in production.
@pragma('vm:entry-point')
void autoTrackingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_AutoTrackingTaskHandler());
}

/// Runs for as long as the foreground service is alive — which, on Android,
/// is until [AutoTrackingService.stop] is called, independent of whether the
/// app's own UI is open, backgrounded, or swiped from recents.
///
/// Unlike the paid `flutter_background_geolocation` plugin this replaces,
/// there is only **one** handler, not a UI-isolate/headless-isolate pair: the
/// task handler isolate is the single place activity events and location
/// fixes are ever processed, whether or not the app is in the foreground. See
/// [AutoTrackingService]'s doc comment for the rest of the shape.
class _AutoTrackingTaskHandler extends TaskHandler {
  final _dao = AutoDetectionDao();
  StreamSubscription<ar.Activity>? _activitySub;
  StreamSubscription<Position>? _positionSub;
  Timer? _stillnessTimer;
  var _moving = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Plugins are not registered automatically in every background-isolate
    // context. Without this, the first sqflite/geolocator call can throw
    // MissingPluginException and the whole detection is silently lost — see
    // the equivalent guard the previous (paid-plugin) implementation carried,
    // preserved here out of caution even though flutter_foreground_task's own
    // FlutterEngine is expected to register plugins itself.
    DartPluginRegistrant.ensureInitialized();
    _activitySub =
        ar.FlutterActivityRecognition.instance.activityStream.listen(_onActivity);
  }

  /// A ride-shaped activity report from the platform classifier.
  ///
  /// `ON_BICYCLE` is treated the same as `IN_VEHICLE`: Google's and Apple's
  /// classifiers routinely mistake a motorcycle for a bicycle at low speed
  /// (both are two-wheeled, non-pedestrian, engine noise aside — neither
  /// classifier listens for engine noise), so excluding it would just move
  /// the false-negative rate rather than remove it.
  static bool _isVehicleLike(ar.ActivityType type) =>
      type == ar.ActivityType.IN_VEHICLE || type == ar.ActivityType.ON_BICYCLE;

  void _onActivity(ar.Activity activity) {
    // LOW confidence is closer to noise than signal for a binary
    // moving/not-moving decision — better to miss a brief flicker than open
    // (or close) a detection on a guess the classifier itself doesn't trust.
    if (activity.confidence == ar.ActivityConfidence.LOW) return;

    if (_isVehicleLike(activity.type)) {
      _stillnessTimer?.cancel();
      _stillnessTimer = null;
      if (_moving) return;
      _moving = true;
      unawaited(_maybeBegin());
    } else if (_moving && _stillnessTimer == null) {
      // Five minutes of non-vehicle activity before declaring the journey
      // over — matches the paid plugin's stopTimeout, tuned against Dhaka
      // traffic specifically: a long signal or a level crossing routinely
      // exceeds two minutes, and splitting one commute into three "rides" is
      // worse than a slightly late stop.
      _stillnessTimer = Timer(const Duration(minutes: 5), () {
        _stillnessTimer = null;
        _moving = false;
        unawaited(_positionSub?.cancel());
        _positionSub = null;
        unawaited(AutoTrackingService.endDetection(_dao));
      });
    }
  }

  /// Opens a detection and starts collecting fixes, unless the rider has
  /// restricted auto-tracking to an active-hours window and the current time
  /// falls outside it.
  ///
  /// **Reduced fidelity vs the paid plugin, by design-for-now:** the old
  /// implementation pushed the schedule into the OS's own scheduler, which
  /// stopped GPS entirely outside the window. This reads the window fresh out
  /// of `SharedPreferences` (with `reload()` — this isolate's cached copy can
  /// otherwise miss an edit made from the Settings screen's isolate) at the
  /// moment a candidate trip starts, and only gates *starting* a detection.
  /// A trip already in progress when the window ends is left to finish rather
  /// than cut off mid-journey — simpler, and arguably the more honest
  /// behaviour, but it does mean a rider who starts riding one minute before
  /// their window closes keeps getting tracked past it.
  Future<void> _maybeBegin() async {
    if (!await _withinScheduleWindow()) {
      _moving = false;
      return;
    }
    await AutoTrackingService.beginDetection(
      _dao,
      AutoTriggerSource.activityRecognition,
    );
    _startPositionStream();
  }

  Future<bool> _withinScheduleWindow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool(AutoTrackingService.prefsScheduleEnabled) ?? false)) {
      return true;
    }
    final startMin =
        prefs.getInt(AutoTrackingService.prefsScheduleStartMin) ?? 7 * 60;
    final endMin =
        prefs.getInt(AutoTrackingService.prefsScheduleEndMin) ?? 22 * 60;
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    return nowMin >= startMin && nowMin < endMin;
  }

  /// HIGH rather than NAVIGATION/bestForNavigation: nobody is watching a live
  /// readout on an auto-tracked ride, and the post-hoc polyline is
  /// indistinguishable. Same reasoning as the auto GPS profile in
  /// `ride_recording_provider.dart`. No `AndroidSettings.
  /// foregroundNotificationConfig` here — the task handler running at all
  /// *is* this app's active foreground service (the "Watching for rides"
  /// notification from [AutoTrackingService.start]), which is what lets
  /// Android grant background location in the first place; a second, nested
  /// foreground-service request from geolocator would be redundant at best
  /// and a duplicate notification at worst.
  void _startPositionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
    _positionSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) => unawaited(AutoTrackingService.recordFix(_dao, position)),
      onError: (Object error) => debugPrint('[auto-tracking] position error $error'),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Nothing to poll: activity and location both arrive as pushed stream
    // events, not on a timer. The repeat event exists only because
    // ForegroundTaskOptions.eventAction requires *some* action; kept as a
    // no-op rather than removed so the intent (this is a deliberate choice,
    // not an oversight) is visible to the next person reading this file.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // The service going away is not the same as the journey ending — unlike
    // TERMINATE in the old plugin, this can happen mid-ride (OS memory
    // pressure, `allowAutoRestart` losing the race). Deliberately does NOT
    // close an open detection here: every fix already on disk survives (see
    // AutoDetectionDao.appendFix), and a detection left `recording` is closed
    // by `closeStaleRecordingDetections()` at next launch, dated to its last
    // real fix rather than to whenever the app happens to reopen.
    await _activitySub?.cancel();
    await _positionSub?.cancel();
    _stillnessTimer?.cancel();
  }
}

/// Configures and owns background ride detection.
///
/// ## Why not the paid plugin
///
/// This is the free-tier stand-in for `flutter_background_geolocation`,
/// adopted 2026-08-28 to avoid the licence purchase while the product is
/// pre-revenue (see `docs/HANDOFF_Document.md`'s backlog for the paid
/// plugin's pros/cons, and
/// `docs/archives/flutter_background_geolocation-2026-08-28/` for its old
/// implementation, kept in case the paid plugin is worth revisiting later).
/// It combines three free (MIT) pieces instead of one paid one:
///
/// - `flutter_activity_recognition` for the "are they moving" signal
///   (`ActivityRecognitionClient` on Android, `CMMotionActivityManager` on
///   iOS) — OS-managed, effectively free of battery cost.
/// - `flutter_foreground_task` for a persistent Android foreground service
///   that keeps that signal alive after the app is swiped from recents, plus
///   `autoRunOnBoot` for surviving a reboot.
/// - `geolocator` (already a dependency for in-ride recording) for the actual
///   fixes, started only once vehicle motion is seen.
///
/// **Known gap, accepted for now:** on iOS, the task handler does not survive
/// the rider force-quitting ThrottleIQ from the app switcher — only Android's
/// foreground service does. `flutter_background_geolocation`'s iOS
/// significant-location-change wake-up is *also* documented as not surviving
/// a user-initiated force-quit (only an OS-initiated kill for memory), so the
/// practical gap is narrower than it first looks, but it is not zero. Not
/// gating the free-tier ship on this.
///
/// ## Battery
///
/// Same shape as before: GPS stays off until the platform reports vehicle
/// motion. The persistent foreground-service notification itself costs
/// effectively nothing (no wakelock beyond `allowWakeLock: true`'s CPU
/// keep-awake); the activity classifier is OS-managed. Any change that polls
/// location on a timer to "check if they're riding" destroys that and must
/// not be made.
class AutoTrackingService {
  AutoTrackingService._();
  static final AutoTrackingService instance = AutoTrackingService._();

  static const _uuid = Uuid();
  static const _prefsEnabled = 'auto_tracking_enabled';
  static const _prefsCurrentDetection = 'auto_tracking_current_detection';

  // Package-visible (not private) so the task-handler isolate above can read
  // the same keys without a second copy of the string literals drifting out
  // of sync.
  static const prefsScheduleEnabled = 'auto_tracking_schedule_enabled';
  static const prefsScheduleStartMin = 'auto_tracking_schedule_start_min';
  static const prefsScheduleEndMin = 'auto_tracking_schedule_end_min';

  var _configured = false;

  /// Whether the rider has turned auto-tracking on.
  ///
  /// Opt-in, and off by default. All-day motion monitoring with "Always"
  /// location is not something to switch on for someone without asking — it
  /// is also the harder App Store / Play review conversation, and a
  /// privacy-policy change.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabled, value);
  }

  /// Whether the rider has restricted auto-tracking to a daily window,
  /// rather than watching all day. Off by default — full-day is the feature
  /// as originally shipped, and a rider who never opens this control should
  /// keep getting exactly that.
  static Future<bool> isScheduleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsScheduleEnabled) ?? false;
  }

  static Future<void> setScheduleEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsScheduleEnabled, value);
  }

  /// The active window, as minutes since local midnight. Defaults to 7am–10pm
  /// — a plausible waking-hours guess for a first-time toggle, not a claim
  /// about any particular rider's schedule.
  static Future<(int startMinutes, int endMinutes)> getScheduleWindow() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getInt(prefsScheduleStartMin) ?? 7 * 60,
      prefs.getInt(prefsScheduleEndMin) ?? 22 * 60,
    );
  }

  /// [startMinutes] must be strictly less than [endMinutes] — an overnight
  /// window that wraps past midnight isn't supported by this single-window
  /// picker (see the Settings UI, which enforces this before calling here).
  static Future<void> setScheduleWindow(
      int startMinutes, int endMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsScheduleStartMin, startMinutes);
    await prefs.setInt(prefsScheduleEndMin, endMinutes);
  }

  /// Prepares the foreground task. Safe to call more than once.
  ///
  /// Deliberately does **not** start tracking — [start] does, and only when
  /// the rider has opted in.
  Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    // initCommunicationPort() is called once, at process start, in main.dart
    // — not here. It has to run before the isolate that receives a restored
    // (post-reboot, post-relaunch) service's messages exists, which is
    // earlier than any rider opt-in check this method could gate on.
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Auto-tracking',
        channelDescription:
            'Shown while ThrottleIQ is watching for a ride to start.',
        priority: NotificationPriority.MIN,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Push-driven (activity/location streams), not polled — see this
        // class's "Battery" note. The repeat interval only feeds
        // onRepeatEvent's deliberate no-op.
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
      ),
    );
  }

  /// Begins watching for rides. No-op unless the rider has opted in.
  ///
  /// Collects the two permissions this needs beyond location (already
  /// gathered by [AutoTrackingNotifier.enable] before this is ever called):
  /// activity recognition, without which the platform classifier never
  /// starts, and — Android 13+ — the notification permission the persistent
  /// "watching for rides" notification needs to actually show.
  Future<bool> start() async {
    if (!await isEnabled()) return false;
    await configure();

    final activityPermission =
        await ar.FlutterActivityRecognition.instance.checkPermission();
    if (activityPermission != ar.ActivityPermission.GRANTED) {
      final requested =
          await ar.FlutterActivityRecognition.instance.requestPermission();
      if (requested != ar.ActivityPermission.GRANTED) return false;
    }

    if (Platform.isAndroid) {
      if (await FlutterForegroundTask.checkNotificationPermission() !=
          NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      // Best-effort: several OEMs kill a foreground service anyway unless
      // the app is exempted from battery optimization. Declining this
      // dialog doesn't fail `start()` — the service still runs, just less
      // reliably on those OEMs.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    if (await FlutterForegroundTask.isRunningService) return true;
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'ThrottleIQ',
      notificationText: 'Watching for rides',
      callback: autoTrackingTaskCallback,
    );
    return result is ServiceRequestSuccess;
  }

  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// No-op: unlike the paid plugin's native OS scheduler, this
  /// implementation reads the active-hours window fresh out of
  /// `SharedPreferences` at the moment each candidate trip starts (see
  /// `_AutoTrackingTaskHandler._withinScheduleWindow`), so there is nothing
  /// to push into an already-running service. Kept as a method — rather than
  /// deleted — so the call sites in `auto_tracking_provider.dart` that edit
  /// the schedule don't need to know which implementation is behind this
  /// service.
  Future<void> applyScheduleChange() async {}

  // ── Shared work, callable from the task-handler isolate or this one ────

  /// Opens a detection, unless one is already open.
  ///
  /// The id is held in `SharedPreferences` rather than in a field because the
  /// task-handler isolate and this one cannot see each other's memory.
  static Future<void> beginDetection(
    AutoDetectionDao dao,
    String triggerSource,
  ) async {
    final existing = await dao.currentRecording();
    if (existing != null) return;

    final id = _uuid.v4();
    await dao.insertDetection(
      id: id,
      startedAt: DateTime.now(),
      triggerSource: triggerSource,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCurrentDetection, id);
  }

  static Future<void> endDetection(AutoDetectionDao dao) async {
    final current = await dao.currentRecording();
    if (current == null) return;
    await dao.closeDetection(current['id'] as String, DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCurrentDetection);
  }

  /// Appends a fix to the open detection.
  ///
  /// Fixes that arrive with no detection open are dropped rather than
  /// implicitly opening one: a fix can outlive its stillness timer closing
  /// the detection, and treating a late straggler as the start of a new
  /// journey is how a parked bike becomes a fresh "ride".
  static Future<void> recordFix(AutoDetectionDao dao, Position position) async {
    final current = await dao.currentRecording();
    if (current == null) return;

    await dao.appendFix(
      detectionId: current['id'] as String,
      timestamp: position.timestamp,
      lat: position.latitude,
      lng: position.longitude,
      speedMs: position.speed < 0 ? 0 : position.speed,
      accuracyM: position.accuracy,
      altitudeM: position.altitude,
      headingDeg: position.heading < 0 ? null : position.heading,
    );
  }
}
