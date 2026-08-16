import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/daos/auto_detection_dao.dart';

/// Entry point for the background isolate.
///
/// **Must be a top-level function annotated `@pragma('vm:entry-point')`** —
/// the tree-shaker has no way to see that the platform side calls this, and
/// without the annotation it is removed from release builds, producing an
/// auto-tracker that works perfectly in debug and never fires in production.
///
/// This runs with **no access to the app's Riverpod container**, because it is
/// a genuinely separate isolate with its own memory. That is the whole reason
/// auto-tracking can't simply call `RideRecordingNotifier.startRide()`: the
/// notifier and every field it holds live in the UI isolate and do not exist
/// here. So this writes raw observations to SQLite and nothing else; turning
/// them into a ride happens on the UI isolate at next launch, in
/// `AutoRideReconcilerService`.
@pragma('vm:entry-point')
void backgroundGeolocationHeadlessTask(bg.HeadlessEvent event) async {
  // Plugins are not registered automatically in a background isolate. Without
  // this, the first sqflite call throws MissingPluginException and the whole
  // detection is silently lost.
  DartPluginRegistrant.ensureInitialized();

  final dao = AutoDetectionDao();

  switch (event.name) {
    case bg.Event.MOTIONCHANGE:
      final location = event.event as bg.Location;
      if (location.isMoving) {
        await AutoTrackingService.beginDetection(
          dao,
          AutoTriggerSource.activityRecognition,
        );
      } else {
        await AutoTrackingService.endDetection(dao);
      }
      break;

    case bg.Event.LOCATION:
      final location = event.event as bg.Location;
      await AutoTrackingService.recordFix(dao, location);
      break;

    case bg.Event.TERMINATE:
      // The app process is going away but the plugin keeps running. Nothing to
      // do — every fix is already on disk (see AutoDetectionDao.appendFix) and
      // a detection left open is closed by closeStaleRecordingDetections() at
      // next launch.
      break;
  }
}

/// Configures and owns background ride detection.
///
/// ## Why a paid plugin
///
/// Reliable all-day trip detection needs four things that have to cooperate:
/// platform activity recognition, iOS significant-location-change, an Android
/// foreground service that survives OEM battery killers, and a headless Dart
/// isolate. `flutter_background_geolocation` provides all four as one tested
/// unit. The alternative was writing a native `LocationForegroundService` and
/// moving recording state out of the 1,500-line `ride_recording_provider.dart`
/// — weeks of work on the most safety-relevant file in the app, before anyone
/// had confirmed the detection itself works.
///
/// **Licensing:** Android *release* builds require a licence key in
/// `AndroidManifest.xml` (`com.transistorsoft.locationmanager.license`). Debug
/// builds run unlicensed. Without a key, release builds log a licence error
/// and the plugin refuses to start — so this is a hard gate before shipping,
/// not a nag. See the manifest for where the key goes.
///
/// ## Battery
///
/// The whole design exists to keep GPS *off*. In the idle state the plugin
/// runs platform activity recognition and, on iOS, significant-location-change
/// — both OS-managed and effectively free. GPS is only started once the
/// platform reports vehicle motion. Continuous GPS costs 5–10% per hour;
/// this shape costs roughly 3–5% per *day* while not riding. Any change that
/// polls location on a timer to "check if they're riding" destroys that and
/// must not be made.
class AutoTrackingService {
  AutoTrackingService._();
  static final AutoTrackingService instance = AutoTrackingService._();

  static const _uuid = Uuid();
  static const _prefsEnabled = 'auto_tracking_enabled';
  static const _prefsCurrentDetection = 'auto_tracking_current_detection';

  final _dao = AutoDetectionDao();
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

  /// Prepares the plugin. Safe to call more than once.
  ///
  /// Deliberately does **not** start tracking — [start] does, and only when
  /// the rider has opted in.
  Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
    bg.BackgroundGeolocation.onLocation(_onLocation, _onLocationError);
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);

    await bg.BackgroundGeolocation.ready(bg.Config(
      // ── Detection ────────────────────────────────────────────────────
      // HIGH rather than NAVIGATION: nobody is watching a live readout on an
      // auto-tracked ride, and the post-hoc polyline is indistinguishable.
      // Same reasoning as the auto GPS profile in ride_recording_provider.
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 20,

      // Minutes of stillness before the plugin declares the journey over.
      // Five is chosen against Dhaka traffic specifically: a long signal or a
      // level crossing routinely exceeds two minutes, and splitting one
      // commute into three "rides" is worse than a slightly late stop.
      stopTimeout: 5,

      // ── Survival ─────────────────────────────────────────────────────
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
      heartbeatInterval: 60,

      // ── Android foreground service ───────────────────────────────────
      foregroundService: true,
      notification: bg.Notification(
        title: 'ThrottleIQ',
        text: 'Watching for rides',
        sticky: false,
        priority: bg.Config.NOTIFICATION_PRIORITY_MIN,
      ),

      // The plugin's own request flow explains the "Always" upgrade better
      // than a bare system dialog does.
      locationAuthorizationRequest: 'Always',
      backgroundPermissionRationale: bg.PermissionRationale(
        title: 'Let ThrottleIQ record rides automatically?',
        message:
            'ThrottleIQ needs background location to notice when you start '
            'riding and log the ride without you tapping start.',
        positiveAction: 'Change to Always Allow',
        negativeAction: 'Cancel',
      ),

      // ── Storage ──────────────────────────────────────────────────────
      // The plugin keeps its own SQLite store and HTTP uploader. Both are
      // switched off: fixes go into this app's own `auto_fixes` table so the
      // reconciler reads one source of truth, and ThrottleIQ uploads through
      // its existing outbox, not a second network path.
      autoSync: false,
      maxDaysToPersist: 3,

      // Verbose in debug only — this plugin is extremely chatty.
      debug: false,
      logLevel: kDebugMode ? bg.Config.LOG_LEVEL_WARNING : bg.Config.LOG_LEVEL_OFF,
    ));

    bg.BackgroundGeolocation.registerHeadlessTask(
      backgroundGeolocationHeadlessTask,
    );
  }

  /// Begins watching for rides. No-op unless the rider has opted in.
  Future<bool> start() async {
    if (!await isEnabled()) return false;
    await configure();
    final state = await bg.BackgroundGeolocation.start();
    return state.enabled;
  }

  Future<void> stop() async {
    if (!_configured) return;
    await bg.BackgroundGeolocation.stop();
  }

  // ── Event handlers (UI isolate) ───────────────────────────────────────
  //
  // These mirror the headless handlers exactly. Both paths exist because the
  // plugin delivers to whichever isolate is alive: the UI isolate when the app
  // is running, the headless one when it isn't. Keeping the two in step is why
  // the actual work lives in the static helpers below rather than being
  // written twice.

  void _onMotionChange(bg.Location location) {
    unawaited(location.isMoving
        ? beginDetection(_dao, AutoTriggerSource.activityRecognition)
        : endDetection(_dao));
  }

  void _onLocation(bg.Location location) => unawaited(recordFix(_dao, location));

  void _onLocationError(bg.LocationError error) {
    // Location errors during monitoring are expected and frequent (no sky
    // view, permission revoked mid-journey, airplane mode). A dropped fix is
    // survivable — the reconciler works from whatever arrived — so this is
    // deliberately not surfaced to the rider.
    debugPrint('[auto-tracking] location error ${error.code}: ${error.message}');
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    debugPrint(
        '[auto-tracking] activity ${event.activity} @ ${event.confidence}%');
  }

  // ── Shared work, callable from either isolate ─────────────────────────

  /// Opens a detection, unless one is already open.
  ///
  /// The id is held in `SharedPreferences` rather than in a field because the
  /// two isolates cannot see each other's memory: the headless isolate may
  /// open a detection that the UI isolate later has to close.
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
  /// implicitly opening one: the plugin emits occasional locations while
  /// stationary (heartbeat, geofence evaluation), and treating those as the
  /// start of a journey is how a parked bike becomes a 12-hour "ride".
  static Future<void> recordFix(AutoDetectionDao dao, bg.Location location) async {
    final current = await dao.currentRecording();
    if (current == null) return;

    final coords = location.coords;
    await dao.appendFix(
      detectionId: current['id'] as String,
      timestamp: DateTime.tryParse(location.timestamp)?.toLocal() ??
          DateTime.now(),
      lat: coords.latitude,
      lng: coords.longitude,
      speedMs: coords.speed < 0 ? 0 : coords.speed,
      accuracyM: coords.accuracy,
      altitudeM: coords.altitude,
      headingDeg: coords.heading < 0 ? null : coords.heading,
    );
  }
}
