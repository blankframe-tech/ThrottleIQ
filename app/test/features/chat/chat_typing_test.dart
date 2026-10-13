import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/realtime_connection_manager.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';
import 'package:throttleiq/features/chat/data/repositories/chat_typing_channel.dart';
import 'package:throttleiq/features/chat/domain/typing_indicator_controller.dart';

import '../../core/realtime/fake_clock.dart';
import '../../core/realtime/in_memory_realtime_store.dart';

void main() {
  group('TypingIndicatorController', () {
    late FakeClock clock;
    late List<bool> sent;
    late TypingIndicatorController controller;

    setUp(() {
      clock = FakeClock();
      sent = [];
      controller = TypingIndicatorController(
        send: sent.add,
        clock: clock.call,
        timerFactory: clock.timer,
      );
    });

    test('a burst of keystrokes sends one "true", not one per character', () {
      for (final text in ['h', 'he', 'hel', 'hell', 'hello']) {
        controller.onTextChanged(text);
        clock.elapse(const Duration(milliseconds: 150));
      }
      expect(sent, [true]);
    });

    test('keeps refreshing every 3 s while typing continues', () {
      for (var i = 0; i < 20; i++) {
        controller.onTextChanged('x' * (i + 1));
        clock.elapse(const Duration(milliseconds: 500));
      }
      // 10 s of typing: t=0, 3, 6, 9.
      expect(sent, [true, true, true, true]);
    });

    test('4 s of silence sends "false"', () {
      controller.onTextChanged('hi');
      clock.elapse(const Duration(seconds: 3, milliseconds: 999));
      expect(sent, [true]);
      clock.elapse(const Duration(milliseconds: 1));
      expect(sent, [true, false]);
    });

    test('clearing the field or sending stops immediately', () {
      controller.onTextChanged('hi');
      controller.onTextChanged('');
      expect(sent, [true, false]);

      controller.onTextChanged('again');
      controller.onSent();
      expect(sent, [true, false, true, false]);
      clock.elapse(const Duration(seconds: 10));
      expect(sent, hasLength(4), reason: 'no stray idle timer');
    });

    test('dispose mid-word sends a final "false" and then nothing', () {
      controller.onTextChanged('hi');
      controller.dispose();
      controller.onTextChanged('ignored');
      clock.elapse(const Duration(seconds: 10));
      expect(sent, [true, false]);
    });

    test('never sends "false" without a prior "true"', () {
      controller.onSent();
      controller.onTextChanged('   ');
      controller.dispose();
      expect(sent, isEmpty);
    });
  });

  group('isPeerTyping', () {
    final t = DateTime.utc(2026, 10, 7, 9);

    test('true only while typing and fresher than the expiry', () {
      final p = ChatPresence(typing: true, serverTime: t);
      expect(isPeerTyping(p, localNow: t.add(const Duration(seconds: 5))), isTrue);
      expect(isPeerTyping(p, localNow: t.add(kTypingExpiry)), isFalse,
          reason: 'writer died mid-word');
      expect(
          isPeerTyping(ChatPresence(typing: false, serverTime: t), localNow: t),
          isFalse);
      expect(isPeerTyping(null, localNow: t), isFalse);
    });

    test('uses the server clock offset', () {
      final p = ChatPresence(typing: true, serverTime: t);
      // Phone 10 s behind the server: by server time this is 12 s old.
      expect(
          isPeerTyping(p,
              localNow: t.add(const Duration(seconds: 2)),
              serverTimeOffsetMs: 10000),
          isFalse);
    });
  });

  group('ChatTypingChannel', () {
    late FakeClock clock;
    late InMemoryRealtimeStore store;
    late ChatTypingChannel channel;

    setUp(() {
      clock = FakeClock();
      store = InMemoryRealtimeStore(serverClock: clock.call);
      channel = ChatTypingChannel(RealtimeServices(
        store: store,
        connections: RealtimeConnectionManager(store),
        health: RealtimeHealthMonitor(store),
      ));
    });

    test('only deterministic DM ids are supported', () {
      expect(channel.supports('alice_bob'), isTrue);
      expect(channel.supports('legacyRandomId'), isFalse);
      expect(
          ChatTypingChannel(RealtimeServices.disabled()).supports('alice_bob'),
          isFalse);
    });

    test('writer → reader: typing shows, and clears when the writer drops',
        () async {
      final seen = <bool?>[];
      final sub = channel
          .watchPresence('alice_bob', 'alice')
          .listen((p) => seen.add(p?.typing));
      await pumpEventQueue();

      await channel.setTyping('alice_bob', 'alice', true);
      await pumpEventQueue();
      expect(store.onDisconnectPaths, {'chat_presence/alice_bob/alice'});

      store.setOnline(false); // alice's app dies
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [null, true, null]);
    });

    test('the server stamps ts, so readers can expire it', () async {
      await channel.setTyping('alice_bob', 'alice', true);
      final p = ChatPresence.tryParse(
          store.valueAt('chat_presence/alice_bob/alice'))!;
      expect(p.serverTime, clock.now);
    });
  });
}
