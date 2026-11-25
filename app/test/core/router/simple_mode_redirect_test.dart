import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/router/app_router.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/simple/presentation/providers/simple_bike_provider.dart';

class _Rider extends Fake implements User {
  @override
  String? get displayName => 'Rider';
}

class _Context extends Fake implements BuildContext {}

/// Simple mode (#240) through the real GoRouter redirect: the signed-in
/// target, the end-of-ride target and the Start-ride widget target are all
/// /home/record, which must land on the Simple home.
void main() {
  Future<String? Function(String)> redirectWith(Map<String, Object> prefs,
      {BikeEntity? bike}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_Rider())),
      if (bike != null) simpleBikeProvider.overrideWithValue(bike),
    ]);
    addTearDown(container.dispose);
    container.listen(authStateProvider, (_, __) {});
    container.read(appModulesProvider);
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);

    final config = container.read(routerProvider).configuration;
    return (loc) => config.topRedirect(
          _Context(),
          GoRouterState(
            config,
            uri: Uri.parse(loc),
            // As in GoRouter: the matched location has no query.
            matchedLocation: loc.split('?').first,
            fullPath: loc,
            pathParameters: const {},
            pageKey: ValueKey(loc),
          ),
        ) as String?;
  }

  test('simple mode: sign-in, end of ride and the widget land on Simple home',
      () async {
    final redirect = await redirectWith({'module_simple': true});
    expect(redirect('/auth/login'), '/home/simple');
    expect(redirect('/home/record'), '/home/simple');
    expect(redirect('/home/maintenance'), '/home/simple-bike');
    expect(redirect('/home/simple'), isNull);
    expect(redirect('/ride/active'), isNull);
    expect(redirect('/home/maintenance/fuel/add?bikeId=b1'), isNull);
  });

  test("simple mode: another bike's maintenance alert opens that bike",
      () async {
    final redirect = await redirectWith({'module_simple': true},
        bike: BikeEntity(
            id: 'b1',
            userId: 'u1',
            brand: 'Yamaha',
            model: 'MT-15',
            createdAt: DateTime(2026, 1, 1)));
    expect(redirect('/home/maintenance?bikeId=b1'), '/home/simple-bike');
    expect(redirect('/home/maintenance?bikeId=b2'), isNull);
  });

  test('full mode is unchanged and the simple tabs bounce home', () async {
    final redirect = await redirectWith({});
    expect(redirect('/auth/login'), '/home/record');
    expect(redirect('/home/record'), isNull);
    expect(redirect('/home/simple'), '/home/record');
    expect(redirect('/home/simple-bike'), '/home/record');
  });

  test('the three simple tabs are shell branches; rides has a detail route',
      () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);
    final shell = container
        .read(routerProvider)
        .configuration
        .routes
        .whereType<StatefulShellRoute>()
        .single;
    final roots = {
      for (final b in shell.branches)
        (b.routes.single as GoRoute).path: b.routes.single as GoRoute,
    };
    for (final tab in const AppModules(simple: true).tabs) {
      expect(roots, contains(tab));
    }
    expect(
        roots['/home/simple-rides']!.routes.whereType<GoRoute>().map(
              (r) => r.path,
            ),
        [':rideId']);
  });
}
