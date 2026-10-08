import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/auth/presentation/screens/onboarding_manifest.dart';
import 'package:throttleiq/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:throttleiq/features/auth/presentation/widgets/onboarding_slide_page.dart';
import 'package:throttleiq/features/auth/presentation/widgets/tour_floating_banner.dart';
import 'package:throttleiq/features/ride/presentation/providers/jam_label_provider.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

final _en = AppLocalizationsEn();

/// The demo tour (Settings › "See Demo & Feature Tour"), hosted in a minimal
/// router so "Show me", the floating banner and finishing all navigate for
/// real. Every "Show me" destination is a stand-in page carrying the banner,
/// the way AppShell and SettingsScreen do.
Widget _app({
  AppAppearance appearance = AppAppearance.defaultAppearance,
  Locale locale = const Locale('en'),
  bool jam = false,
  bool reduceMotion = true,
  double textScale = 1,
}) {
  final router = GoRouter(
    initialLocation: '/auth/onboarding',
    routes: [
      GoRoute(
        path: '/auth/onboarding',
        builder: (_, __) => const OnboardingScreen(demoMode: true),
      ),
      for (final path in [
        '/settings',
        '/profile',
        '/home/record',
        '/home/stats',
        '/home/profile',
        '/home/maintenance',
        '/home/places',
        '/home/social',
      ])
        GoRoute(
          path: path,
          builder: (_, __) => Scaffold(
            body: Stack(children: [
              Center(child: Text('screen:$path')),
              const Positioned(
                  left: 0, right: 0, bottom: 0, child: TourFloatingBanner()),
            ]),
          ),
        ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => null),
      canLabelJamsProvider.overrideWith((ref) => jam),
    ],
    child: MaterialApp.router(
      theme: AppTheme.build(appearance),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  // The spotlight's pulse is stopped under reduce-motion, so this settles.
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('walks forward and back through every step, then exits',
      (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await _settle(tester);

    final slides = onboardingSlides(_en);
    expect(find.text(_en.tourStepCounter(1, kOnboardingSlideCount)), findsWidgets);
    expect(find.text(slides.first.title), findsOneWidget);
    // Nowhere to go back to on step 1.
    expect(
        tester.widget<OutlinedButton>(find.byKey(const ValueKey('tour-back'))).onPressed,
        isNull);

    for (var i = 1; i < kOnboardingSlideCount; i++) {
      await _tap(tester, 'tour-next');
      expect(find.text(_en.tourStepCounter(i + 1, kOnboardingSlideCount)),
          findsWidgets);
      expect(find.text(slides[i].title), findsOneWidget);
      // "Show me" only where the step has a live screen to open.
      expect(find.byKey(const ValueKey('tour-show-me')),
          slides[i].showMeRoute == null ? findsNothing : findsOneWidget);
    }
    expect(find.text(_en.tourFinish), findsOneWidget);

    await _tap(tester, 'tour-back');
    expect(find.text(slides[kOnboardingSlideCount - 2].title), findsOneWidget);
    expect(find.text(_en.tourNext), findsOneWidget);

    await _tap(tester, 'tour-next');
    await _tap(tester, 'tour-next'); // Finish: demo mode returns to Settings.
    expect(find.text('screen:/settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Show me" opens the live screen; the banner returns or advances',
      (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await _settle(tester);

    await _tap(tester, 'tour-show-me');
    expect(find.text('screen:/home/record'), findsOneWidget);
    expect(find.byKey(const ValueKey('tour-banner')), findsOneWidget);
    expect(find.text(_en.tourStepCounter(1, kOnboardingSlideCount)), findsOneWidget);

    // Back to tour: same step.
    await _tap(tester, 'tour-banner-back');
    expect(find.text(onboardingSlides(_en)[0].title), findsOneWidget);
    expect(find.byKey(const ValueKey('tour-banner')), findsNothing);

    // Show me again, then Next: back in the tour, one step further.
    await _tap(tester, 'tour-show-me');
    await _tap(tester, 'tour-banner-next');
    expect(find.text(onboardingSlides(_en)[1].title), findsOneWidget);
    expect(find.text(_en.tourStepCounter(2, kOnboardingSlideCount)), findsWidgets);
  });

  testWidgets('beta riders see the jam-labelling callout on the cockpit step',
      (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(jam: true));
    await _settle(tester);
    await _tap(tester, 'tour-next'); // → cockpit
    expect(find.text(_en.tourCockpitTitle), findsOneWidget);
    await tester.scrollUntilVisible(find.text(_en.tourCockpitJamTitle), 80,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('ride_cockpit')),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text(_en.tourCockpitJamTitle), findsOneWidget);
    expect(find.text(_en.jamLabelBetaTag), findsOneWidget);
  });

  testWidgets('renders every step in every color mode, shape and brightness',
      (tester) async {
    await _setSize(tester, const Size(390, 844));
    for (final mode in AppColorMode.values) {
      for (final vibe in AppShapeVibe.values) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(_app(
            appearance: AppAppearance(
                colorMode: mode, shapeVibe: vibe, brightness: brightness),
          ));
          await _settle(tester);
          for (var i = 1; i < kOnboardingSlideCount; i++) {
            await _tap(tester, 'tour-next');
          }
          expect(tester.takeException(), isNull,
              reason: '${mode.name}/${vibe.name}/${brightness.name}');
          // Fresh tree per combination.
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets(
        'fits a small phone at a large text size without overflow '
        '(${locale.languageCode})', (tester) async {
      await _setSize(tester, const Size(320, 568));
      await tester.pumpWidget(_app(locale: locale, jam: true, textScale: 1.3));
      await _settle(tester);
      final l10n = locale.languageCode == 'bn' ? AppLocalizationsBn() : _en;
      for (var i = 0; i < kOnboardingSlideCount; i++) {
        expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
        expect(find.byKey(const ValueKey('tour-next')).hitTestable(),
            findsOneWidget,
            reason: 'Next must stay reachable on step ${i + 1}');
        if (i < kOnboardingSlideCount - 1) await _tap(tester, 'tour-next');
      }
      expect(find.text(l10n.tourFinish), findsOneWidget);
    });
  }

  testWidgets('animates between steps with motion enabled', (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(reduceMotion: false));
    // The spotlight pulses forever, so pump time rather than settle.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('tour-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-transition: both pages are built.
    expect(find.byType(OnboardingSlidePage, skipOffstage: false), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_en.tourStepCounter(2, kOnboardingSlideCount)), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
