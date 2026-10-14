import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/ride/presentation/widgets/recording_gate.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Critique B4: a manual ride asks for while-in-use location only, once;
/// "Allow all the time" sits behind a disclosure the rider sees until they
/// accept it once.
class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator(this.permission, {this.afterRequest});

  LocationPermission permission;
  final LocationPermission? afterRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    if (afterRequest != null) permission = afterRequest!;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  late GeolocatorPlatform original;
  setUp(() {
    original = GeolocatorPlatform.instance;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  group('ensureRideLocationPermission', () {
    test('while-in-use is enough: no upgrade request', () async {
      final geo = _FakeGeolocator(LocationPermission.whileInUse);
      GeolocatorPlatform.instance = geo;
      expect(await ensureRideLocationPermission(), isTrue);
      expect(geo.requests, 0);
    });

    test('asks once when not yet decided', () async {
      final geo = _FakeGeolocator(LocationPermission.denied,
          afterRequest: LocationPermission.whileInUse);
      GeolocatorPlatform.instance = geo;
      expect(await ensureRideLocationPermission(), isTrue);
      expect(geo.requests, 1);
    });

    test('a permanent refusal does not bounce to Settings', () async {
      final geo = _FakeGeolocator(LocationPermission.deniedForever);
      GeolocatorPlatform.instance = geo;
      expect(await ensureRideLocationPermission(), isFalse);
      expect(geo.requests, 0);
      expect(geo.settingsOpened, 0);
    });
  });

  group('ensureBackgroundLocationDisclosure', () {
    /// Calls the disclosure [calls] times, answering each dialog shown with
    /// [accept]. Returns each call's result and how many dialogs appeared.
    Future<({List<bool> results, int dialogs})> callTimes(WidgetTester tester,
        {required int calls, required bool accept}) async {
      final results = <bool>[];
      var dialogs = 0;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await ensureBackgroundLocationDisclosure(context)),
            child: const Text('go'),
          ),
        ),
      ));
      for (var i = 0; i < calls; i++) {
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          dialogs++;
          await tester
              .tap(find.byType(accept ? FilledButton : TextButton).last);
          await tester.pumpAndSettle();
        }
      }
      return (results: results, dialogs: dialogs);
    }

    testWidgets('shown once; accepting is remembered', (tester) async {
      GeolocatorPlatform.instance =
          _FakeGeolocator(LocationPermission.whileInUse);
      final r = await callTimes(tester, calls: 2, accept: true);
      expect(r.dialogs, 1);
      expect(r.results, [true, true]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kBackgroundDisclosureAcceptedPref), isTrue);
    });

    testWidgets('"Not now" returns false and is asked again next time',
        (tester) async {
      GeolocatorPlatform.instance =
          _FakeGeolocator(LocationPermission.whileInUse);
      final r = await callTimes(tester, calls: 2, accept: false);
      expect(r.dialogs, 2);
      expect(r.results, [false, false]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kBackgroundDisclosureAcceptedPref), isNull);
    });

    testWidgets('skipped when "Allow all the time" is already granted',
        (tester) async {
      GeolocatorPlatform.instance = _FakeGeolocator(LocationPermission.always);
      final r = await callTimes(tester, calls: 1, accept: true);
      expect(r.dialogs, 0);
      expect(r.results, [true]);
    });
  });
}
