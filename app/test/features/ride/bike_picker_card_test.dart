import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/ride/presentation/widgets/bike_picker_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The Record screen's bike picker.
///
/// Tested here rather than through `RecordScreen`, which reads
/// `FirebaseAuth.instance` in `initState` and can't be pumped without a live
/// Firebase app — the same reason the skin picker is its own widget
/// (`Issues.md` §15).
///
/// The regression this file exists for: switching bikes used to navigate to
/// `/home/profile` instead of switching the bike. The card has since become
/// the Record screen's photo hero and the dropdown a bottom sheet, but the
/// contract under test is unchanged — picking a bike switches it, in place.
BikeEntity bike(String id, String model, {bool active = false, int rides = 0}) =>
    BikeEntity(
      id: id,
      userId: 'u1',
      brand: 'Ronin',
      model: model,
      isActive: active,
      rideCount: rides,
      createdAt: DateTime(2026, 1, 1),
    );

/// Stands in for the real notifier, which would hit the bike DAO and
/// `currentUserProvider`. Records what the picker asked for.
class FakeGarageNotifier extends GarageNotifier {
  FakeGarageNotifier(this._bikes);

  final List<BikeEntity> _bikes;
  final List<String> setActiveCalls = [];

  @override
  Future<List<BikeEntity>> build() async => _bikes;

  @override
  Future<void> setActiveBike(String id) async => setActiveCalls.add(id);
}

void main() {
  late FakeGarageNotifier notifier;

  Widget harness(List<BikeEntity> bikes, BikeEntity active,
      {List<Route<dynamic>>? pushed}) {
    notifier = FakeGarageNotifier(bikes);
    return ProviderScope(
      overrides: [garageProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        // M3's InkSparkle shader can't be decoded by the test engine, so any
        // tap throws before it lands — see `Issues.md` §15.
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [
          if (pushed != null) _RouteRecorder(pushed),
        ],
        home: Scaffold(
          body: BikePickerCard(activeBike: active, titleText: 'Evening'),
        ),
      ),
    );
  }

  testWidgets('switches the active bike without leaving the screen',
      (tester) async {
    // The reported bug: tapping "Change" navigated to Garage. Assert both
    // halves — the bike actually changes, AND no page route is pushed.
    final bikes = [
      bike('b1', 'Nightfox', active: true, rides: 12),
      bike('b2', 'Daybreak', rides: 3),
    ];
    final pushed = <Route<dynamic>>[];
    await tester.pumpWidget(harness(bikes, bikes[0], pushed: pushed));
    await tester.pumpAndSettle();
    // MaterialApp pushes its own "/" home route at startup; only what
    // happens from here on is navigation the picker caused.
    pushed.clear();

    await tester.tap(find.byType(BikePickerCard));
    await tester.pumpAndSettle();
    expect(find.text('Ronin Daybreak'), findsWidgets);

    await tester.tap(find.text('Ronin Daybreak').last);
    await tester.pumpAndSettle();

    expect(notifier.setActiveCalls, ['b2']);
    // The picker sheet's own route is expected; a MaterialPageRoute would
    // mean we navigated away, which is the bug.
    expect(pushed.whereType<MaterialPageRoute>(), isEmpty);
  });

  testWidgets('offers every bike in the garage', (tester) async {
    final bikes = [
      bike('b1', 'Nightfox', active: true),
      bike('b2', 'Daybreak'),
      bike('b3', 'Ridgeline'),
    ];
    await tester.pumpWidget(harness(bikes, bikes[0]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BikePickerCard));
    await tester.pumpAndSettle();

    for (final b in bikes) {
      expect(find.text(b.displayName), findsWidgets, reason: b.id);
    }
  });

  testWidgets('a single-bike garage shows no picker to open', (tester) async {
    // A dropdown whose only option is the current one is a control that
    // can't do anything.
    final bikes = [bike('b1', 'Nightfox', active: true)];
    await tester.pumpWidget(harness(bikes, bikes[0]));
    await tester.pumpAndSettle();

    // The hero names the bike, and offers no way to change it.
    expect(find.text('RONIN NIGHTFOX'), findsOneWidget);
    expect(find.text('CHANGE'), findsNothing);

    await tester.tap(find.byType(BikePickerCard));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('re-picking the bike already active does nothing',
      (tester) async {
    final bikes = [
      bike('b1', 'Nightfox', active: true),
      bike('b2', 'Daybreak'),
    ];
    await tester.pumpWidget(harness(bikes, bikes[0]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BikePickerCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ronin Nightfox').last);
    await tester.pumpAndSettle();

    // No DAO write and no `invalidateSelf` for a no-op selection.
    expect(notifier.setActiveCalls, isEmpty);
  });
}

class _RouteRecorder extends NavigatorObserver {
  _RouteRecorder(this.pushed);
  final List<Route<dynamic>> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}
