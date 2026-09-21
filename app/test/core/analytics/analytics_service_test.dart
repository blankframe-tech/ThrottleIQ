import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/analytics/analytics_service.dart';

/// issues §83.27. The guarantees that make this "privacy-respecting" are the
/// things worth pinning: it is off in debug, off when the rider opts out, it
/// can only send events from the closed list, and screen names are patterns.
class _FakeSink implements AnalyticsSink {
  final events = <(String, Map<String, Object>?)>[];
  final screens = <String>[];
  final collection = <bool>[];
  @override
  Future<void> setCollectionEnabled(bool enabled) async => collection.add(enabled);
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async =>
      events.add((name, parameters));
  @override
  Future<void> logScreen(String name) async => screens.add(name);
}

class _ThrowingSink extends _FakeSink {
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) =>
      throw StateError('boom');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sends nothing in debug builds, even when enabled', () async {
    final sink = _FakeSink();
    final a = AnalyticsService(sink: sink, debugMode: true);
    await a.init();
    await a.log(AnalyticsEvent.logIn, param: AnalyticsParam.method, value: 'email');
    await a.logScreen('/home/record');
    expect(sink.events, isEmpty);
    expect(sink.screens, isEmpty);
    expect(sink.collection.last, isFalse, reason: 'SDK collection stays off in debug');
  });

  test('a rider who opted out sends nothing, and the choice survives a restart', () async {
    SharedPreferences.setMockInitialValues({AnalyticsService.prefsKey: false});
    final sink = _FakeSink();
    final a = AnalyticsService(sink: sink, debugMode: false);
    await a.init();
    expect(a.enabled, isFalse);
    expect(sink.collection.last, isFalse);
    await a.log(AnalyticsEvent.rideStarted);
    await a.logScreen('/home/record');
    expect(sink.events, isEmpty);
    expect(sink.screens, isEmpty);
  });

  test('enabled: sends the event name and only the one coarse parameter', () async {
    final sink = _FakeSink();
    final a = AnalyticsService(sink: sink, debugMode: false);
    await a.init();
    expect(sink.collection.last, isTrue);

    await a.log(AnalyticsEvent.rideStarted, param: AnalyticsParam.source, value: 'auto');
    await a.log(AnalyticsEvent.bikeAdded);

    // Compared as text: Dart maps use identity equality, so a record holding a
    // map would never match a literal.
    expect(sink.events.map((e) => '${e.$1} ${e.$2}').toList(),
        ['ride_started {source: auto}', 'bike_added null']);
  });

  test('a parameter without a value (or vice versa) is dropped, not sent half-formed', () async {
    final sink = _FakeSink();
    final a = AnalyticsService(sink: sink, debugMode: false);
    await a.log(AnalyticsEvent.logIn, param: AnalyticsParam.method);
    await a.log(AnalyticsEvent.logIn, value: 'email');
    expect(sink.events, [('login', null), ('login', null)]);
  });

  test('the event list is closed and contains no identifying names', () {
    final names = AnalyticsEvent.values.map((e) => e.wireName).toSet();
    expect(names, {
      'sign_up', 'login', 'ride_started', 'ride_ended', 'ride_shared',
      'bike_added', 'route_saved',
    });
    // The only parameters that exist at all.
    expect(AnalyticsParam.values.map((p) => p.name).toSet(), {'method', 'source'});
  });

  test('a repeated screen is logged once (rebuilds and pops back)', () async {
    final sink = _FakeSink();
    final a = AnalyticsService(sink: sink, debugMode: false);
    await a.logScreen('/ride/summary/:rideId');
    await a.logScreen('/ride/summary/:rideId');
    await a.logScreen('/home/record');
    expect(sink.screens, ['/ride/summary/:rideId', '/home/record']);
  });

  test('toggling off in Settings takes effect at once and persists', () async {
    final sink = _FakeSink();
    final a = AnalyticsService(sink: sink, debugMode: false);
    await a.init();
    await a.setEnabled(false);
    expect(a.enabled, isFalse);
    expect(sink.collection.last, isFalse);
    await a.log(AnalyticsEvent.rideShared);
    expect(sink.events, isEmpty);
    expect((await SharedPreferences.getInstance()).getBool(AnalyticsService.prefsKey), isFalse);
  });

  test('a failing sink never throws into the caller', () async {
    final a = AnalyticsService(sink: _ThrowingSink(), debugMode: false);
    await a.log(AnalyticsEvent.rideEnded, param: AnalyticsParam.source, value: 'manual');
  });
}
