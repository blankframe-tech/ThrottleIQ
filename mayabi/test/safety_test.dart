import 'package:test/test.dart';
import 'package:throttleiq_mayabi/throttleiq_mayabi.dart';
import 'dart:async';

class _FakeTimer implements Timer {
  _FakeTimer(this.cb);
  final void Function() cb;
  bool cancelled = false;
  void fire() {
    if (!cancelled) cb();
  }

  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

void main() {
  group('SafetyCheck', () {
    late List<SafetyEvent> escalated;
    late List<_FakeTimer> timers;
    late SafetyCheck check;
    final crash = SafetyEvent(
        SafetyEventKind.crash, DateTime(2026, 10, 17, 9), 23.78, 90.41);

    setUp(() {
      escalated = [];
      timers = [];
      check = SafetyCheck(
        onEscalate: escalated.add,
        timer: (d, cb) {
          final t = _FakeTimer(cb);
          timers.add(t);
          return t;
        },
      );
    });

    test('no answer: escalates when the countdown ends', () {
      check.raise(crash);
      expect(check.pending, crash);
      timers.single.fire();
      expect(escalated, [crash]);
      expect(check.pending, isNull);
    });

    test('"I\'m OK" cancels; nothing is sent', () {
      check.raise(crash);
      check.riderIsOk();
      timers.single.fire();
      expect(escalated, isEmpty);
      expect(check.pending, isNull);
    });

    test('"Get help" escalates at once, exactly once', () {
      check.raise(crash);
      check.riderNeedsHelp();
      timers.single.fire();
      expect(escalated, hasLength(1));
    });

    test('a second event while asking is folded into the first', () {
      check.raise(crash);
      check.raise(
          SafetyEvent(SafetyEventKind.unusualStop, DateTime(2026), null, null));
      expect(timers, hasLength(1));
      expect(check.pending, crash);
    });
  });

  group('SOS links', () {
    test('Android sms: comma-joined, %20 body', () {
      expect(
          sosSmsUri(['+880 17-1234-5678', '01811 223344'], 'SOS help',
                  iOS: false)
              .toString(),
          'sms:+8801712345678,01811223344?body=SOS%20help');
    });
    test('iOS sms: addresses form', () {
      expect(sosSmsUri(['01712345678'], 'a&b', iOS: true).toString(),
          'sms:/open?addresses=01712345678&body=a%26b');
    });
    test('undialable numbers dropped; none left is null', () {
      expect(sosSmsUri(['n/a', '01712345678'], 'x', iOS: false).toString(),
          'sms:01712345678?body=x');
      expect(sosSmsUri(['', 'none'], 'x', iOS: false), isNull);
    });
    test('999 and tel cleanup', () {
      expect(telUri(kBangladeshEmergencyNumber).toString(), 'tel:999');
      expect(telUri('+880 (17) 1234-5678').toString(), 'tel:+8801712345678');
      expect(telUri('--'), isNull);
    });
    test('message has the live link and map pin when known', () {
      final m = sosMessage(
          intro: 'SOS', liveUrl: 'https://x/live/t', lat: 23.78, lng: 90.41);
      expect(m,
          'SOS\nLive location: https://x/live/t\nLast known spot: https://maps.google.com/?q=23.7800000,90.4100000');
      expect(sosMessage(intro: 'SOS'), 'SOS');
      expect(sosMessage(intro: 'এসওএস', liveLabel: 'লাইভ লোকেশন', liveUrl: 'u'),
          'এসওএস\nলাইভ লোকেশন: u');
    });
  });
}
