import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../i18n/l10n_lookup.dart';
import '../../l10n/app_localizations.dart';

/// Local notifications: crash escalation, ride-confirmation prompts, and the
/// weekly digest.
///
/// `flutter_local_notifications` was already a dependency before this file
/// existed, but nothing ever initialised it — so no notification of any kind
/// could be delivered. Everything here is new plumbing rather than a change to
/// existing behaviour.
///
/// ## Channels
///
/// Three Android channels, deliberately separate so a rider can silence the
/// digest without silencing a crash alert:
///
/// - **crash** — `Importance.max`, full-screen intent, alarm category. The one
///   channel that is allowed to take over a locked screen.
/// - **rides** — ride confirmation prompts. Default importance.
/// - **digest** — the weekly summary. Low importance, no sound.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _initialised = false;

  // ── Channels ──────────────────────────────────────────────────────────
  static const crashChannelId = 'throttleiq_crash';
  static const ridesChannelId = 'throttleiq_rides';
  static const digestChannelId = 'throttleiq_digest';
  static const maintenanceChannelId = 'throttleiq_maintenance';

  // ── Notification ids ──────────────────────────────────────────────────
  // Fixed ids so a second delivery replaces the first rather than stacking.
  static const crashNotificationId = 9001;
  static const confirmPromptId = 9002;
  static const weeklyDigestId = 9003;

  /// Maintenance and paperwork alerts take ids in
  /// [maintenanceIdBase, maintenanceIdBase + maintenanceIdSpan) — see
  /// `MaintenanceAlerts.notificationIdFor`.
  static const maintenanceIdBase = 9100;
  static const maintenanceIdSpan = 800;

  /// Payload prefix of a maintenance alert: `maint:<bikeId>`.
  static const maintenancePayloadPrefix = 'maint:';

  // ── Action ids ────────────────────────────────────────────────────────
  static const actionImOk = 'crash_im_ok';
  static const actionConfirmRide = 'confirm_ride';

  /// Invoked when the rider taps "I'm OK" on a crash notification.
  ///
  /// Wired by `RideRecordingNotifier` to the same `dismissCrashAlert()` the
  /// in-app countdown button calls — one cancellation path, two entry points,
  /// so a crash dismissed from the lock screen can't diverge from one
  /// dismissed in the app.
  VoidCallback? onCrashDismissed;

  /// Invoked when the rider taps a ride-confirmation notification.
  /// [rideId] is carried in the notification payload.
  void Function(String rideId)? onConfirmRideTapped;

  /// Invoked when the rider taps a maintenance or paperwork alert.
  void Function(String bikeId)? onMaintenanceTapped;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    tzdata.initializeTimeZones();
    // A device whose zone can't be read or isn't in the tz database still
    // gets notifications. It used to fall back silently to UTC, which put
    // the 9 pm daily summary at 03:00 in Bangladesh (issues §101.C8); now
    // the device's UTC offset picks a fixed-offset zone instead.
    String? zoneName;
    try {
      zoneName = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      debugPrint('[notifications] local timezone unavailable: $e');
    }
    tz.setLocalLocation(
        resolveLocalLocation(zoneName, DateTime.now().timeZoneOffset));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Requested explicitly in [requestPermissions] instead, so the
          // prompt appears at a moment the rider understands rather than on
          // first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          requestCriticalPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );

    await _createAndroidChannels(await savedL10n());
  }

  Future<void> _createAndroidChannels(AppLocalizations l10n) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(AndroidNotificationChannel(
      crashChannelId,
      l10n.notifChannelCrash,
      description: l10n.notifChannelCrashDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    await android.createNotificationChannel(AndroidNotificationChannel(
      ridesChannelId,
      l10n.notifChannelRides,
      description: l10n.notifChannelRidesDesc,
      importance: Importance.defaultImportance,
    ));

    await android.createNotificationChannel(AndroidNotificationChannel(
      maintenanceChannelId,
      l10n.notifChannelMaintenance,
      description: l10n.notifChannelMaintenanceDesc,
      importance: Importance.defaultImportance,
    ));

    await android.createNotificationChannel(AndroidNotificationChannel(
      digestChannelId,
      l10n.notifChannelDigest,
      description: l10n.notifChannelDigestDesc,
      importance: Importance.low,
      playSound: false,
    ));
  }

  /// Asks for notification permission.
  ///
  /// Separate from [init] so the ask can be attached to the moment the rider
  /// turns auto-tracking on — where "we'll notify you about detected rides"
  /// is self-explanatory — rather than being fired blind at first launch.
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      // Android 14+ gates full-screen intents behind their own permission.
      // Without it a crash alert degrades to an ordinary heads-up notification
      // — still delivered, just not able to take over a locked screen.
      await android.requestFullScreenIntentPermission();
      return granted;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  /// Escalates a crash to something a rider with a pocketed phone can actually
  /// see and cancel.
  ///
  /// This is the fix for the gap that made auto-tracking unsafe: the in-app
  /// 60-second countdown is only dismissible from a screen the rider is
  /// looking at, and on an auto-started ride nobody is. Without this, the
  /// first the rider knew of a false positive was their emergency contacts
  /// being called.
  ///
  /// `fullScreenIntent` + the alarm category is what lets this appear over a
  /// locked screen. It is deliberately `ongoing` and non-dismissible by swipe:
  /// swiping away a crash alert must not silently cancel the countdown *or*
  /// silently let it run — the rider has to answer it.
  Future<void> showCrashAlert({required int secondsRemaining}) async {
    await init();
    final l10n = await savedL10n();
    await _plugin.show(
      crashNotificationId,
      l10n.notifCrashTitle,
      l10n.notifCrashBody(secondsRemaining),
      NotificationDetails(
        android: AndroidNotificationDetails(
          crashChannelId,
          l10n.notifChannelCrash,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          enableVibration: true,
          actions: [
            AndroidNotificationAction(
              actionImOk,
              l10n.notifImOk,
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
          categoryIdentifier: 'throttleiq_crash',
        ),
      ),
      payload: actionImOk,
    );
  }

  Future<void> cancelCrashAlert() async {
    await _plugin.cancel(crashNotificationId);
  }

  /// Asks which bike an auto-detected ride was on, immediately after it ends.
  ///
  /// Fired at ride end rather than batched into the day-end summary because
  /// attribution accuracy decays with memory: "which bike was 4:30pm?" is easy
  /// twenty minutes later and guesswork by evening. The day-end summary still
  /// exists (see [showDailySummary]) — it reports, this one asks.
  Future<void> showRideConfirmation({
    required String rideId,
    required String bikeLabel,
    required double distanceKm,
  }) async {
    await init();
    final l10n = await savedL10n();
    await _plugin.show(
      confirmPromptId,
      l10n.notifRideDetectedTitle(distanceKm.toStringAsFixed(1)),
      l10n.notifRideDetectedBody(bikeLabel),
      NotificationDetails(
        android: AndroidNotificationDetails(
          ridesChannelId,
          l10n.notifChannelRides,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          actions: [
            AndroidNotificationAction(
              actionConfirmRide,
              l10n.notifConfirm,
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: rideId,
    );
  }

  /// The day-end update: what you rode today.
  ///
  /// [rideCount] counts manual rides and the ones auto-tracking caught that
  /// the rider forgot to record ([notRecordedCount] of them), with jam-split
  /// fragments already merged — see `daily_ride_summary.dart`. Callable from
  /// the auto-tracking task-handler isolate as well as the UI one.
  ///
  /// Silent on days with no rides — a tracker that pings you to say nothing
  /// happened is the "daily nag" `hooked_throttleiq.md` warns against, and it
  /// trains riders to swipe the channel away, taking the confirmation prompts
  /// and crash alerts' credibility with it.
  Future<void> showDailySummary({
    required int rideCount,
    required double distanceKm,
    required int rideMinutes,
    required int notRecordedCount,
  }) async {
    if (rideCount == 0) return;
    await init();

    final l10n = await savedL10n();
    final body = StringBuffer(
        l10n.notifDigestSummary(rideCount, distanceKm.toStringAsFixed(1)));
    body.write(l10n.notifDigestRideTime(rideMinutes));
    if (notRecordedCount > 0) {
      body.write(l10n.notifDigestNotRecorded(notRecordedCount));
    }

    await _plugin.show(
      weeklyDigestId,
      l10n.notifDigestTitle,
      body.toString(),
      NotificationDetails(
        android: AndroidNotificationDetails(
          digestChannelId,
          l10n.notifChannelDigest,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  /// Schedules the day-end summary for [hour] local time, every day.
  ///
  /// `matchDateTimeComponents: DateTimeComponents.time` is what makes it
  /// recur daily at the same wall-clock hour across DST changes, rather than
  /// drifting the way a fixed 24-hour interval would.
  ///
  /// The scheduled notification is a *trigger*, not the content — the app
  /// wakes, counts the day's rides, and calls [showDailySummary], which stays
  /// silent if there's nothing to say.
  Future<void> scheduleDailySummary({int hour = 21, int minute = 0}) async {
    await init();
    final l10n = await savedL10n();
    await _plugin.zonedSchedule(
      weeklyDigestId,
      l10n.notifDigestTitle,
      l10n.notifDigestTap,
      nextInstanceOf(tz.TZDateTime.now(tz.local), hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          digestChannelId,
          l10n.notifChannelDigest,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailySummary() => _plugin.cancel(weeklyDigestId);

  NotificationDetails _maintenanceDetails(AppLocalizations l10n) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          maintenanceChannelId,
          l10n.notifChannelMaintenance,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// A maintenance or paperwork alert, now. [id] is stable per item so a
  /// later alert for the same item replaces this one.
  Future<void> showMaintenanceAlert({
    required int id,
    required String title,
    required String body,
    required String bikeId,
  }) async {
    await init();
    final l10n = await savedL10n();
    await _plugin.show(id, title, body, _maintenanceDetails(l10n),
        payload: '$maintenancePayloadPrefix$bikeId');
  }

  /// The same alert, scheduled for [at] — for limits set by the calendar
  /// (brake fluid age, tax token expiry) that fall due whether or not the
  /// app is opened.
  Future<void> scheduleMaintenanceAlert({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String bikeId,
  }) async {
    await init();
    final l10n = await savedL10n();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      _maintenanceDetails(l10n),
      payload: '$maintenancePayloadPrefix$bikeId',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Routes a maintenance alert that cold-started the app. A tap on a
  /// notification while the app was killed never reaches
  /// `onDidReceiveNotificationResponse`; it's only available here. Call once
  /// the tap callbacks are registered.
  Future<void> handleMaintenanceLaunchTap() async {
    try {
      await init();
      final details = await _plugin.getNotificationAppLaunchDetails();
      final payload = details?.notificationResponse?.payload;
      if (details?.didNotificationLaunchApp != true || payload == null) return;
      if (payload.startsWith(maintenancePayloadPrefix)) {
        onMaintenanceTapped
            ?.call(payload.substring(maintenancePayloadPrefix.length));
      }
    } catch (e) {
      debugPrint('[notifications] launch details unavailable: $e');
    }
  }

  /// The next [hour]:[minute] on the wall clock of [now]'s zone. Tomorrow
  /// is built from the calendar date rather than by adding 24 hours, so a
  /// DST change overnight doesn't shift it to 20:00 or 22:00 (issues
  /// §101.C9).
  @visibleForTesting
  static tz.TZDateTime nextInstanceOf(tz.TZDateTime now, int hour, int minute) {
    final location = now.location;
    var scheduled =
        tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = tz.TZDateTime(
          location, now.year, now.month, now.day + 1, hour, minute);
    }
    return scheduled;
  }

  /// The zone to schedule against. [name] is what the device reported; if
  /// it's missing or unknown, a whole-hour [deviceOffset] maps to the
  /// matching `Etc/GMT` zone (the tz database inverts the sign, so +6 h is
  /// `Etc/GMT-6`). Failing that: Asia/Dhaka for +6 h, otherwise UTC.
  /// Never throws.
  @visibleForTesting
  static tz.Location resolveLocalLocation(String? name, Duration deviceOffset) {
    if (name != null && name.isNotEmpty) {
      try {
        return tz.getLocation(name);
      } catch (e) {
        debugPrint('[notifications] unknown timezone "$name": $e');
      }
    }
    if (deviceOffset.inMinutes % 60 == 0) {
      final hours = deviceOffset.inHours;
      final etc = hours == 0
          ? 'Etc/GMT'
          : (hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}');
      try {
        return tz.getLocation(etc);
      } catch (e) {
        debugPrint('[notifications] no fixed-offset zone $etc: $e');
      }
    }
    if (deviceOffset == const Duration(hours: 6)) {
      try {
        return tz.getLocation('Asia/Dhaka');
      } catch (e) {
        debugPrint('[notifications] Asia/Dhaka unavailable: $e');
      }
    }
    return tz.UTC;
  }

  void _onResponse(NotificationResponse response) {
    switch (response.actionId) {
      case actionImOk:
        onCrashDismissed?.call();
        return;
      case actionConfirmRide:
        final rideId = response.payload;
        if (rideId != null && rideId.isNotEmpty) {
          onConfirmRideTapped?.call(rideId);
        }
        return;
    }

    // Body tap (no action id). The payload disambiguates which notification.
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    if (payload == actionImOk) {
      onCrashDismissed?.call();
    } else if (payload.startsWith(maintenancePayloadPrefix)) {
      onMaintenanceTapped
          ?.call(payload.substring(maintenancePayloadPrefix.length));
    } else {
      onConfirmRideTapped?.call(payload);
    }
  }
}
