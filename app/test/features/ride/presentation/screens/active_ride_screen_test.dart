import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/presentation/providers/jam_label_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/live_ride_places_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/ride/presentation/screens/active_ride_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The cockpit's controls against a fake recorder (§83.28): pause/resume,
/// end ride, discard, the crash gate and the idle redirect. The real notifier
/// needs GPS, sensors and a foreground service; the screen only needs its
/// state and the transition methods.
class _FakeRecorder extends StateNotifier<RideRecordingState>
    implements RideRecordingNotifier {
  _FakeRecorder(super.state);

  final calls = <String>[];

  @override
  Future<void> pauseRide() async {
    calls.add('pause');
    state = state.copyWith(status: RecordingStatus.paused);
  }

  @override
  Future<void> resumeRide() async {
    calls.add('resume');
    state = state.copyWith(status: RecordingStatus.active);
  }

  @override
  Future<void> cancelRide() async {
    calls.add('cancel');
    state = const RideRecordingState();
  }

  /// Idles the provider before returning, as the real one does.
  @override
  Future<String?> stopRide() async {
    calls.add('stop');
    state = const RideRecordingState();
    return 'ride-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real one queries Firestore for nearby places.
class _NoPlaces extends StateNotifier<List<PlaceEntity>>
    implements LiveRidePlacesNotifier {
  _NoPlaces() : super(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRecorder recorder;

  Future<void> pump(WidgetTester tester, RideRecordingState initial,
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    recorder = _FakeRecorder(initial);
    final router = GoRouter(
      initialLocation: '/ride/active',
      routes: [
        GoRoute(
            path: '/ride/active', builder: (_, __) => const ActiveRideScreen()),
        GoRoute(
            path: '/home/record',
            builder: (_, __) => const Scaffold(body: Text('Record tab'))),
        GoRoute(
            path: '/ride/summary/:id',
            builder: (_, s) =>
                Scaffold(body: Text('Summary ${s.pathParameters['id']}'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rideRecordingProvider.overrideWith((ref) => recorder),
        liveRidePlacesProvider.overrideWith((ref) => _NoPlaces()),
        canLabelJamsProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  const active = RideRecordingState(status: RecordingStatus.active);

  testWidgets('Pause pauses the ride, then the same button resumes it',
      (tester) async {
    await pump(tester, active);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Ride kept from last time'), findsNothing);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(recorder.calls, ['pause']);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(recorder.calls, ['pause', 'resume']);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('Pause is disabled while a transition is in flight (§90.C5)',
      (tester) async {
    await pump(
        tester,
        const RideRecordingState(
            status: RecordingStatus.active, transitionPending: true));
    final pause = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Pause'), matching: find.bySubtype<ButtonStyleButton>()));
    expect(pause.onPressed, isNull);
    await tester.tap(find.text('Pause'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(recorder.calls, isEmpty);
  });

  testWidgets('End Ride: a full hold stops the ride and opens its summary',
      (tester) async {
    await pump(tester, active);
    await tester.tap(find.text('End Ride'));
    await tester.pumpAndSettle();

    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('holdToEndButton'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await g.up();
    await tester.pumpAndSettle();

    expect(recorder.calls, ['stop']);
    // Not the Record tab: stopRide() idles the provider first, and the idle
    // redirect must not win the race with the summary navigation.
    expect(find.text('Summary ride-1'), findsOneWidget);
    expect(find.text('Record tab'), findsNothing);
  });

  testWidgets('End Ride: "Keep riding" keeps recording', (tester) async {
    await pump(tester, active);
    await tester.tap(find.text('End Ride'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Keep riding'));
    await tester.pumpAndSettle();

    expect(recorder.calls, isEmpty);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('Discard ride: "Keep recording" keeps it', (tester) async {
    await pump(tester, active);
    await tester.tap(find.text('Discard ride'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this ride?'), findsOneWidget);

    await tester.tap(find.text('Keep recording'));
    await tester.pumpAndSettle();
    expect(recorder.calls, isEmpty);
    expect(find.text('Discard this ride?'), findsNothing);
    expect(find.text('End Ride'), findsOneWidget);
  });

  testWidgets('Discard ride: confirming cancels it and returns to Record',
      (tester) async {
    await pump(tester, active);
    await tester.tap(find.text('Discard ride'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(recorder.calls, ['cancel']);
    expect(find.text('Record tab'), findsOneWidget);
  });

  testWidgets(
      'crash alerts are off (shadow mode): a detected crash shows no takeover',
      (tester) async {
    // SensorConstants.crashAlertsEnabled is false until tier 2 ships, so a
    // crashDetected state (e.g. restored off disk) must not cover the cockpit.
    await pump(
        tester,
        const RideRecordingState(
            status: RecordingStatus.active,
            crashDetected: true,
            crashCountdown: 42));
    expect(find.text('CRASH DETECTED'), findsNothing);
    expect(find.text("I'M OK"), findsNothing);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(recorder.calls, ['pause']);
  });

  testWidgets('the Indriyo mirror toggle is hidden until Indriyo is turned on',
      (tester) async {
    // Off by default (Settings → Advanced → Indriyo).
    await pump(tester, active);
    expect(find.byIcon(Icons.radar_rounded), findsNothing);
    expect(find.byTooltip('Toggle Indriyo ADAS Mirror'), findsNothing);
  });

  testWidgets('a restored ride shows the "kept from last time" banner',
      (tester) async {
    await pump(
        tester,
        const RideRecordingState(
            status: RecordingStatus.paused, restoredFromPreviousSession: true));
    expect(find.text('Ride kept from last time'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('an idle recorder sends the rider back to Record',
      (tester) async {
    await pump(tester, const RideRecordingState());
    expect(find.text('Record tab'), findsOneWidget);
  });

  group('alert flash (#32)', () {
    const braking = RideRecordingState(
        status: RecordingStatus.active, activeAlert: RideAlert.hardBraking);
    final overlay = find.byKey(const Key('alertFlashOverlay'));

    testWidgets('on by default: hard braking flashes the map', (tester) async {
      await pump(tester, braking);
      expect(overlay, findsOneWidget);
    });

    testWidgets('turned off in Settings: no flash overlay', (tester) async {
      await pump(tester, braking, prefs: {'settings_alert_flash': false});
      expect(overlay, findsNothing);
      expect(find.text('Pause'), findsOneWidget);
    });
  });
}
