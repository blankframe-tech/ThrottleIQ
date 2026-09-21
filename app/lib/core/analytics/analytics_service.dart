import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only things ThrottleIQ ever reports (issues §83.27).
///
/// A closed list on purpose. Privacy here is not "we promise to be careful with
/// arbitrary events" but "there is no call that can send anything else": each
/// case is a funnel step, carries at most one coarse, non-identifying parameter
/// from [AnalyticsParam], and never a user id, name, email, location, ride
/// figure, message or free text.
enum AnalyticsEvent {
  signUp('sign_up'),
  logIn('login'),
  rideStarted('ride_started'),
  rideEnded('ride_ended'),
  rideShared('ride_shared'),
  bikeAdded('bike_added'),
  routeSaved('route_saved');

  const AnalyticsEvent(this.wireName);
  final String wireName;
}

/// The single allowed parameter and its allowed values, per event.
enum AnalyticsParam {
  /// `email` | `google` (sign up / login).
  method,

  /// `manual` | `auto` (ride started / ended).
  source,
}

/// Where events actually go. Swapped for a fake in tests.
abstract class AnalyticsSink {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> logEvent(String name, Map<String, Object>? parameters);
  Future<void> logScreen(String name);
}

class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    await _fa.setAnalyticsCollectionEnabled(enabled);
    // No advertising anything, whatever the toggle says: this is a usage
    // counter, not an ad product. (The AD_ID permission is also stripped from
    // the Android manifest.)
    await _fa.setConsent(
      analyticsStorageConsentGranted: enabled,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) =>
      _fa.logEvent(name: name, parameters: parameters);

  @override
  Future<void> logScreen(String name) => _fa.logScreenView(screenName: name);
}

/// Privacy-respecting usage counting: screen views and a short fixed list of
/// funnel events, off in debug builds, and off for any rider who opts out in
/// Settings → Privacy & Safety.
///
/// Never throws and never blocks the caller: analytics failing must not be a
/// reason a screen or a ride misbehaves.
class AnalyticsService {
  AnalyticsService({AnalyticsSink? sink, bool? debugMode})
      : _sink = sink ?? FirebaseAnalyticsSink(),
        _debugMode = debugMode ?? kDebugMode;

  /// App-wide instance. A singleton (not only a provider) because callers
  /// include notifiers and services with no `ref`.
  static AnalyticsService instance = AnalyticsService();

  static const prefsKey = 'analytics_enabled';

  final AnalyticsSink _sink;
  final bool _debugMode;

  bool _enabled = true;
  bool get enabled => _enabled;

  String? _lastScreen;

  /// Reads the rider's choice and tells the SDK. Call once at startup.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefsKey) ?? true;
      await _apply();
    } catch (e) {
      debugPrint('Analytics init failed (non-fatal): $e');
    }
  }

  /// The Settings switch. Persisted, and applied to the SDK immediately.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
      await _apply();
    } catch (e) {
      debugPrint('Analytics setEnabled failed (non-fatal): $e');
    }
  }

  Future<void> _apply() => _sink.setCollectionEnabled(_enabled && !_debugMode);

  /// Records a funnel step. [param] is the one coarse parameter that event
  /// allows, or null.
  Future<void> log(AnalyticsEvent event, {AnalyticsParam? param, String? value}) async {
    if (!_enabled || _debugMode) return;
    try {
      await _sink.logEvent(
        event.wireName,
        param == null || value == null ? null : {param.name: value},
      );
    } catch (e) {
      debugPrint('Analytics log failed (non-fatal): $e');
    }
  }

  /// Records a screen view. [name] must be a route *pattern*
  /// (`/ride/summary/:rideId`), never a resolved path containing an id.
  Future<void> logScreen(String name) async {
    if (!_enabled || _debugMode) return;
    if (name == _lastScreen) return; // a rebuild or a pop back to the same page
    _lastScreen = name;
    try {
      await _sink.logScreen(name);
    } catch (e) {
      debugPrint('Analytics logScreen failed (non-fatal): $e');
    }
  }
}
