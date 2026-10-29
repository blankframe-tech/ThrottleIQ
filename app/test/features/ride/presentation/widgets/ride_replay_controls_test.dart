import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/widgets/ride_replay_controls.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  late ValueNotifier<int?> position;

  Future<void> pump(WidgetTester tester, List<double> speeds) async {
    position = ValueNotifier(null);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RideReplayControls(speedsMs: speeds, position: position),
      ),
    ));
  }

  final speeds = List<double>.generate(100, (i) => i.toDouble());

  testWidgets('play advances the marker to the end and stops', (tester) async {
    await pump(tester, speeds);
    expect(position.value, isNull);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride_replay_play_pause')));
    await tester.pump(RideReplayControls.tick * 3);
    expect(position.value, greaterThan(0));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.pump(RideReplayControls.replayDuration);
    expect(position.value, 99);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    // 99 m/s readout at the last point.
    expect(find.text('356 km/h'), findsOneWidget);
  });

  testWidgets('pause holds the position', (tester) async {
    await pump(tester, speeds);
    await tester.tap(find.byKey(const Key('ride_replay_play_pause')));
    await tester.pump(RideReplayControls.tick * 4);
    await tester.tap(find.byKey(const Key('ride_replay_play_pause')));
    final held = position.value;
    await tester.pump(const Duration(seconds: 2));
    expect(position.value, held);
  });

  testWidgets('dragging the scrubber moves the position', (tester) async {
    await pump(tester, speeds);
    await tester.drag(
        find.byKey(const Key('ride_replay_scrubber')), const Offset(200, 0));
    expect(position.value, greaterThan(0));
  });

  testWidgets('play at the end restarts from the first point', (tester) async {
    await pump(tester, speeds);
    position.value = 99;
    await tester.tap(find.byKey(const Key('ride_replay_play_pause')));
    await tester.pump(RideReplayControls.tick);
    expect(position.value, lessThan(10));
    await tester.tap(find.byKey(const Key('ride_replay_play_pause')));
  });
}
