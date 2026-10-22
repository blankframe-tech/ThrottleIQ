import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/features/ride/presentation/providers/parking_pin_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/ride/presentation/widgets/ride_actions_menu.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _FakeRecorder extends StateNotifier<RideRecordingState>
    implements RideRecordingNotifier {
  _FakeRecorder(super.state);

  int pauses = 0;

  @override
  Future<void> pauseRide() async {
    pauses++;
    state = state.copyWith(status: RecordingStatus.paused);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRecorder recorder;
  late ProviderContainer container;

  Future<void> pumpMenu(WidgetTester tester, RideRecordingState initial,
      {bool places = true}) async {
    SharedPreferences.setMockInitialValues({'module_places': places});
    recorder = _FakeRecorder(initial);
    final router = GoRouter(
      initialLocation: '/ride/active',
      routes: [
        GoRoute(
          path: '/ride/active',
          builder: (_, __) => Scaffold(
            appBar: AppBar(actions: const [RideActionsMenu()]),
          ),
        ),
        GoRoute(
            path: '/home/places',
            builder: (_, __) => const Scaffold(body: Text('Places tab'))),
        GoRoute(
            path: '/home/stats',
            builder: (_, __) => const Scaffold(body: Text('Rides tab'))),
      ],
    );
    container = ProviderContainer(overrides: [
      rideRecordingProvider.overrideWith((ref) => recorder),
    ]);
    addTearDown(container.dispose);
    // Built up front as AppShell does in the app, so its async prefs load
    // has landed before the menu reads it.
    container.read(appModulesProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String item) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  const fix = LatLng(23.81, 90.41);

  testWidgets('minimize goes to Places', (tester) async {
    await pumpMenu(
        tester, const RideRecordingState(status: RecordingStatus.active));
    await choose(tester, 'Minimize');
    expect(find.text('Places tab'), findsOneWidget);
  });

  testWidgets('minimize falls back to Rides when Places is off',
      (tester) async {
    await pumpMenu(
        tester, const RideRecordingState(status: RecordingStatus.active),
        places: false);
    await choose(tester, 'Minimize');
    expect(find.text('Rides tab'), findsOneWidget);
  });

  testWidgets('parking pin drops a pin and pauses the ride', (tester) async {
    await pumpMenu(
        tester,
        const RideRecordingState(
            status: RecordingStatus.active, currentPosition: fix));
    await choose(tester, 'Parking pin');
    expect(recorder.pauses, 1);
    expect(recorder.state.status, RecordingStatus.paused);
    expect(container.read(parkingPinProvider)?.point, fix);
  });

  testWidgets('parking pin is ignored while a transition is pending',
      (tester) async {
    await pumpMenu(
        tester,
        const RideRecordingState(
            status: RecordingStatus.active,
            currentPosition: fix,
            transitionPending: true));
    await choose(tester, 'Parking pin');
    expect(recorder.pauses, 0);
    expect(container.read(parkingPinProvider), isNull);
  });

  testWidgets('no GPS fix: both pin actions explain instead of acting',
      (tester) async {
    await pumpMenu(
        tester, const RideRecordingState(status: RecordingStatus.active));
    await choose(tester, 'Parking pin');
    expect(find.text('No GPS fix yet'), findsOneWidget);
    expect(recorder.pauses, 0);

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await choose(tester, 'Cop checkpoint here');
    expect(find.text('No GPS fix yet'), findsOneWidget);
    expect(find.text('Expires in 24 h'), findsNothing);
  });
}
