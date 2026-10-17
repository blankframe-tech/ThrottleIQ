import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/ride/presentation/widgets/ride_in_progress_bar.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/shared/widgets/app_shell.dart';

class _FakeRideRecordingNotifier extends StateNotifier<RideRecordingState>
    implements RideRecordingNotifier {
  _FakeRideRecordingNotifier(
      {RecordingStatus initialStatus = RecordingStatus.idle})
      : super(RideRecordingState(status: initialStatus));

  void setStatus(RecordingStatus status) {
    state = state.copyWith(status: status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('shellTabIndexForLocation', () {
    test('each tab path maps to its own index', () {
      for (var i = 0; i < shellTabs.length; i++) {
        expect(
          shellTabIndexForLocation(shellTabs[i]),
          i,
          reason: '${shellTabs[i]} should select index $i',
        );
      }
    });

    // The reported bug: maintenance is reached from the garage, but matched no
    // tab prefix and fell through to the Record fallback, so the wrong tab
    // appeared selected while the right screen was shown.
    test('/home/maintenance selects Profile, not Record', () {
      const profile = 4;
      expect(shellTabIndexForLocation('/home/maintenance'), profile);
      expect(shellTabIndexForLocation('/home/maintenance/add'), profile);
      expect(
        shellTabIndexForLocation('/home/maintenance?bikeId=abc123'),
        profile,
      );
      expect(
        shellTabIndexForLocation('/home/maintenance/add?bikeId=abc123'),
        profile,
      );
    });

    test('nested tab paths select their parent tab', () {
      expect(shellTabIndexForLocation('/home/profile/abc123'), 4);
      expect(shellTabIndexForLocation('/home/profile/abc123/edit'), 4);
      expect(shellTabIndexForLocation('/home/places/add'), 1);
      expect(shellTabIndexForLocation('/home/places/xyz'), 1);
    });

    test('query strings are ignored when matching', () {
      expect(shellTabIndexForLocation('/home/places?category=fuel'), 1);
    });

    test('an unknown location falls back to Record', () {
      expect(shellTabIndexForLocation('/home/nonsense'), 2);
      expect(shellTabIndexForLocation('/'), 2);
      expect(shellTabIndexForLocation(''), 2);
    });

    // A prefix match must respect path segment boundaries, or a future
    // '/home/recordings' route would silently steal the Record tab.
    test('does not match on a partial segment', () {
      expect(shellTabIndexForLocation('/home/recordings'), 2);
      expect(shellTabIndexForLocation('/home/socialite'), 2);
    });
  });

  group('AppShell RideInProgressBar integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
        'the strip is hidden when idle, shows when active, and a tap goes to /ride/active',
        (tester) async {
      late _FakeRideRecordingNotifier fakeRecorder;

      final router = GoRouter(
        initialLocation: '/home/places',
        routes: [
          GoRoute(
            path: '/home/places',
            builder: (_, __) => const AppShell(
              child: Scaffold(body: Text('Places Content')),
            ),
          ),
          GoRoute(
            path: '/ride/active',
            builder: (_, __) => const Scaffold(body: Text('Active Cockpit')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideRecordingProvider.overrideWith((ref) {
              fakeRecorder = _FakeRideRecordingNotifier(
                  initialStatus: RecordingStatus.idle);
              return fakeRecorder;
            }),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hidden when idle
      expect(find.textContaining('Recording ride'), findsNothing);
      expect(find.textContaining('Ride paused'), findsNothing);

      // Shows when active
      fakeRecorder.setStatus(RecordingStatus.active);
      await tester.pumpAndSettle();
      expect(find.textContaining('Recording ride'), findsOneWidget);

      // Tap goes to /ride/active
      await tester.tap(find.byType(RideInProgressBar));
      await tester.pumpAndSettle();
      expect(find.text('Active Cockpit'), findsOneWidget);
    });
  });
}
