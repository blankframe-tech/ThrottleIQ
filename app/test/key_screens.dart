import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/firebase_providers.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/auth/presentation/screens/login_screen.dart';
import 'package:throttleiq/features/auth/presentation/screens/register_screen.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/profile/presentation/screens/advanced_settings_screen.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/jam_label_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/live_ride_places_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/ride/presentation/screens/active_ride_screen.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/garage/presentation/screens/garage_screen.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_money.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/riding_conditions.dart';
import 'package:throttleiq/features/maintenance/domain/catalog/schedule_templates.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_profile.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/maintenance_check_row.dart';
import 'package:throttleiq/features/profile/presentation/screens/settings_screen.dart';
import 'package:throttleiq/features/ride/presentation/screens/ride_summary_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Key screens pumped from fixed data with fakes only (no Firebase, GPS or
/// network), shared by the text-scale sweep (#48) and the goldens (#49).
enum KeyScreen {
  cockpit,
  cockpitPaused,
  login,
  register,
  advancedSettings,
  settings,
  rideSummary,
  maintenance,
  garage,
}

/// The cockpit mid-ride: real numbers in every tile.
final _riding = RideRecordingState(
  status: RecordingStatus.active,
  ride: RideEntity(
      id: 'r1',
      userId: 'u1',
      bikeId: 'b1',
      startTime: DateTime(2026, 10, 29, 8)),
  currentSpeedMs: 16.7,
  maxSpeedMs: 24.2,
  distanceM: 12480,
  elapsed: const Duration(minutes: 27, seconds: 41),
  movingSeconds: 1500,
  confidence: 87,
);

class _FakeRecorder extends StateNotifier<RideRecordingState>
    implements RideRecordingNotifier {
  _FakeRecorder(super.state);

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

class _FakeAuth extends StateNotifier<AsyncValue<void>>
    implements AuthNotifier {
  _FakeAuth() : super(const AsyncValue.data(null));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _bike = BikeEntity(
  id: 'b1',
  userId: 'u1',
  brand: 'Bajaj',
  model: 'Pulsar 150',
  odometerKm: 12000,
  totalDistanceM: 1500 * 1000,
  createdAt: DateTime(2025, 1, 1),
);

final _done = RideEntity(
  id: 'r1',
  userId: 'u1',
  bikeId: 'b1',
  startTime: DateTime(2026, 10, 29, 8),
  endTime: DateTime(2026, 10, 29, 8, 27, 41),
  status: RideStatus.completed,
  distanceM: 12480,
  maxSpeedMs: 24.2,
  avgSpeedMs: 7.5,
  movingSeconds: 1500,
  durationSeconds: 1661,
);

final _logs = [
  for (final (i, t) in [ServiceType.oilChange, ServiceType.chain].indexed)
    MaintenanceEntity(
      id: '$i',
      bikeId: 'b1',
      serviceType: t,
      date: DateTime.now().subtract(const Duration(days: 40)),
      odometerKm: 12100,
      createdAt: DateTime.now(),
    ),
];

class _Garage extends GarageNotifier {
  @override
  Future<List<BikeEntity>> build() async => [_bike];
}

class _Logs extends MaintenanceNotifier {
  @override
  Future<List<MaintenanceEntity>> build(String bikeId) async => _logs;
}

class _Configs extends MaintenanceConfigNotifier {
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async =>
      configsFromTemplate(
          bikeId: 'b1', template: templateById('bajaj_pulsar_150'));
}

class _Profile extends MaintenanceProfileNotifier {
  @override
  Future<MaintenanceProfileEntity?> build(String bikeId) async =>
      MaintenanceProfileEntity(
        bikeId: 'b1',
        templateId: 'bajaj_pulsar_150',
        ridingProfile: RidingProfile.severe,
        onboardedAt: DateTime.now(),
      );
}

class _Papers extends PaperworkNotifier {
  @override
  Future<List<PaperworkEntity>> build(String bikeId) async => [
        PaperworkEntity(
          bikeId: 'b1',
          kind: PaperworkKind.taxToken,
          expiresOn: DateTime.now().add(const Duration(days: 12)),
        ),
      ];
}

class _Issues extends PrecheckIssuesNotifier {
  @override
  Future<List<PrecheckIssue>> build(String bikeId) async => [
        PrecheckIssue(
            id: 'p1',
            bikeId: 'b1',
            item: PrecheckItem.chain,
            createdAt: DateTime.now()),
      ];
}

/// Loads the app's real faces so text measures and looks as on a phone (the
/// default test font draws every glyph as a 1em box, about twice too wide).
/// Call once, from `setUpAll`.
Future<void> loadKeyScreenFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The pubspec fonts (Material icons, the Bangla fallback): flutter_test
  // bundles them but doesn't load them.
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in family['fonts'] as List) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
  }
  // IBM Plex and Space Grotesk come from google_fonts, which loads them from
  // `assets/google_fonts/` (bundled so the app never fetches them). With
  // fetching off, a variant the theme or `display()` asks for that isn't
  // bundled fails here instead of throwing on an offline phone.
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final brightness in Brightness.values) {
    AppTheme.build(AppAppearance(brightness: brightness));
  }
  // Every weight passed to display()/cockpitValue() (w800 resolves to w700).
  for (final weight in const [
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.spaceGrotesk(fontWeight: weight);
  }
  await GoogleFonts.pendingFonts();
}

/// Pumps [screen] on a 390×844 phone (iPhone 15 logical size).
Future<void> pumpKeyScreen(
  WidgetTester tester,
  KeyScreen screen, {
  double textScale = 1,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  if (screen == KeyScreen.rideSummary) {
    // The summary loads its GPS track from the local database.
    databaseFactory = databaseFactoryFfi;
    final db = (await tester.runAsync(() async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false));
      await DatabaseHelper.instance.createSchemaForTesting(db);
      return db;
    }))!;
    DatabaseHelper.overrideDatabaseForTesting(db);
    addTearDown(() => DatabaseHelper.overrideDatabaseForTesting(null));
  }

  final Widget page = switch (screen) {
    KeyScreen.cockpit || KeyScreen.cockpitPaused => const ActiveRideScreen(),
    KeyScreen.login => const LoginScreen(),
    KeyScreen.register => const RegisterScreen(),
    KeyScreen.advancedSettings => const AdvancedSettingsScreen(),
    KeyScreen.settings => const SettingsScreen(),
    KeyScreen.rideSummary => const RideSummaryScreen(rideId: 'r1'),
    KeyScreen.maintenance => const MaintenanceScreen(bikeId: 'b1'),
    KeyScreen.garage => const GarageScreen(),
  };
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => page),
  ]);
  final recording = screen == KeyScreen.cockpitPaused
      ? _riding.copyWith(status: RecordingStatus.paused)
      : _riding;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      rideRecordingProvider.overrideWith((ref) => _FakeRecorder(recording)),
      liveRidePlacesProvider.overrideWith((ref) => _NoPlaces()),
      canLabelJamsProvider.overrideWithValue(false),
      authNotifierProvider.overrideWith((ref) => _FakeAuth()),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      rideDetailProvider.overrideWith((ref, id) async => _done),
      garageProvider.overrideWith(_Garage.new),
      maintenanceProvider.overrideWith(_Logs.new),
      maintenanceConfigProvider.overrideWith(_Configs.new),
      maintenanceProfileProvider.overrideWith(_Profile.new),
      isMaintenanceCustomizedProvider.overrideWith((ref, id) async => true),
      bikeUsageProvider.overrideWith((ref, id) async => const BikeUsage(
          UsageStats(
            avgDailyKm: 30,
            rideDistanceKm: 900,
            movingSeconds: 60000,
            durationSeconds: 100000,
          ),
          0)),
      paperworkProvider.overrideWith(_Papers.new),
      precheckIssuesProvider.overrideWith(_Issues.new),
      maintenanceMoneyProvider.overrideWith((ref, id) async =>
          computeMoney(logs: _logs, now: DateTime.now(), distanceKm12m: 3000)),
      canOrderPartsProvider.overrideWithValue(false),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(AppAppearance(brightness: brightness)),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  ));
  if (screen == KeyScreen.settings || screen == KeyScreen.rideSummary) {
    // These keep a spinner or map tile animating, so they never settle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else {
    await tester.pumpAndSettle();
  }
}
