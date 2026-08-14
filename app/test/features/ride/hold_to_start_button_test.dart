import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/widgets/hold_to_start_button.dart';

/// The rounded skins' start control (docs/features.md — Record screen).
///
/// The property under test is the one the control exists for: a ride must not
/// start by accident. Everything here is about *when* onStart fires, not what
/// the ring looks like.
///
/// Two testing notes, both of which cost a debugging round the first time:
///
/// - After the pointer goes down, the animation needs a bare `pump()` before
///   any timed pump. That first frame is where the ticker records its start
///   time; advancing the clock in the same pump that began the gesture leaves
///   the controller at 0.
/// - Never `pumpAndSettle()` while `busy: true`. The spinner it renders is an
///   indeterminate, permanently-running animation, so settling never happens
///   and the test times out rather than failing usefully.
Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

const _hold = Duration(milliseconds: 500);

void main() {
  group('HoldToStartButton', () {
    testWidgets('fires once the hold completes', (tester) async {
      var starts = 0;
      await tester.pumpWidget(_host(HoldToStartButton(
        onStart: () => starts++,
        holdDuration: _hold,
      )));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump(); // ticker start frame
      await tester.pump(const Duration(milliseconds: 600));

      expect(starts, 1);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('does NOT fire when released early', (tester) async {
      // The whole point of the gesture: a brush against the screen, or a
      // half-second press while pulling gloves on, must not start recording.
      var starts = 0;
      await tester.pumpWidget(_host(HoldToStartButton(
        onStart: () => starts++,
        holdDuration: _hold,
      )));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(starts, 0);
    });

    testWidgets('a released hold unwinds back to armed, not stuck part-way',
        (tester) async {
      var starts = 0;
      await tester.pumpWidget(_host(HoldToStartButton(
        onStart: () => starts++,
        holdDuration: _hold,
      )));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      // A second, full hold must still work — i.e. the release genuinely reset
      // the control rather than leaving it part-filled and confused.
      final second = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(starts, 1);

      await second.up();
      await tester.pump();
    });

    testWidgets('fires only once even if held well past completion',
        (tester) async {
      var starts = 0;
      await tester.pumpWidget(_host(HoldToStartButton(
        onStart: () => starts++,
        holdDuration: const Duration(milliseconds: 300),
      )));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();

      expect(starts, 1);
    });

    testWidgets('ignores the gesture entirely when disabled', (tester) async {
      var starts = 0;
      await tester.pumpWidget(_host(HoldToStartButton(
        onStart: () => starts++,
        enabled: false,
        holdDuration: const Duration(milliseconds: 300),
      )));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(starts, 0);
    });

    testWidgets('ignores the gesture while a start is already in flight',
        (tester) async {
      var starts = 0;
      await tester.pumpWidget(_host(HoldToStartButton(
        onStart: () => starts++,
        busy: true,
        holdDuration: const Duration(milliseconds: 300),
      )));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(starts, 0);
      // Busy swaps the label for a spinner.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('re-arms after a start that failed', (tester) async {
      // startRide() can come back without going active (GPS off, permission
      // denied). The control must not be left stuck at 100%.
      var starts = 0;
      Widget build(bool busy) => _host(HoldToStartButton(
            onStart: () => starts++,
            busy: busy,
            holdDuration: const Duration(milliseconds: 300),
          ));

      await tester.pumpWidget(build(false));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(starts, 1);
      await gesture.up();
      await tester.pump();

      // Start goes in flight, then fails and clears.
      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pumpWidget(build(false));
      await tester.pump();

      // A fresh hold works again.
      final second = await tester.startGesture(
        tester.getCenter(find.byType(HoldToStartButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await second.up();
      await tester.pump();

      expect(starts, 2);
    });

    testWidgets('exposes a hold hint to screen readers', (tester) async {
      // A hold gesture is invisible to TalkBack/VoiceOver otherwise.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(HoldToStartButton(onStart: () {})));

      expect(
        find.bySemanticsLabel(RegExp('press and hold', caseSensitive: false)),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
