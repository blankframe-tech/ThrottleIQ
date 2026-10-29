import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:throttleiq/l10n/app_localizations.dart';

/// Key screens pumped from fixed data with fakes only (no Firebase, GPS or
/// network), shared by the text-scale sweep (#48) and the goldens (#49).
enum KeyScreen { cockpit, cockpitPaused, login, register, advancedSettings }

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
  // IBM Plex and Space Grotesk come from google_fonts, which downloads them
  // at runtime but first looks for `<family>_<variant>_<sha256>.ttf` in the
  // app support directory. `test/fonts/` holds those exact files, so
  // google_fonts loads them itself, and a variant missing there fails here.
  GoogleFonts.config.allowRuntimeFetching = false;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory('test/fonts').absolute.path);
  for (final brightness in Brightness.values) {
    AppTheme.build(AppAppearance(brightness: brightness));
  }
  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700);
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

  final Widget page = switch (screen) {
    KeyScreen.cockpit || KeyScreen.cockpitPaused => const ActiveRideScreen(),
    KeyScreen.login => const LoginScreen(),
    KeyScreen.register => const RegisterScreen(),
    KeyScreen.advancedSettings => const AdvancedSettingsScreen(),
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
  await tester.pumpAndSettle();
}
