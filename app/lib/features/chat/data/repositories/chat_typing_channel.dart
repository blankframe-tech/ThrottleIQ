import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/realtime/realtime_location_publisher.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/realtime/realtime_store.dart';

/// A reader treats "typing" as over once the writer's last refresh is this
/// old, so a phone that died mid-word stops showing "typing…" on its own.
const Duration kTypingExpiry = Duration(seconds: 6);

/// One participant's `/chat_presence/{chatId}/{uid}` value.
class ChatPresence {
  const ChatPresence({required this.typing, this.serverTime});

  final bool typing;
  final DateTime? serverTime;

  static ChatPresence? tryParse(Object? raw) {
    if (raw is! Map || raw['typing'] is! bool) return null;
    final ts = raw['ts'];
    return ChatPresence(
      typing: raw['typing'] as bool,
      serverTime: ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt(), isUtc: true)
          : null,
    );
  }
}

/// Whether [presence] means "typing right now". Pure — the room re-evaluates
/// it every second so the indicator expires without a new event.
bool isPeerTyping(
  ChatPresence? presence, {
  required DateTime localNow,
  int serverTimeOffsetMs = 0,
  Duration expiry = kTypingExpiry,
}) {
  if (presence == null || !presence.typing) return false;
  final ts = presence.serverTime;
  if (ts == null) return false;
  final serverNow =
      localNow.toUtc().add(Duration(milliseconds: serverTimeOffsetMs));
  return serverNow.difference(ts) < expiry;
}

/// The RTDB typing indicator for 1:1 chats (`/chat_presence`). See
/// DOCS/For Devs and Contributors/architecture/realtime-database.md.
class ChatTypingChannel {
  ChatTypingChannel(this._realtime);

  final RealtimeServices _realtime;
  final Set<String> _disconnectArmed = {};

  /// Only deterministic DM ids (`<uidA>_<uidB>`) — the rules decide who's a
  /// participant from the id's halves, so a legacy random-id chat can't
  /// have an indicator.
  bool supports(String chatId) =>
      _realtime.isEnabled && chatId.split('_').length == 2;

  RealtimeServices get services => _realtime;

  static String _path(String chatId, String uid) => 'chat_presence/$chatId/$uid';

  /// Publishes this rider's typing state. The first `true` also arms an
  /// `onDisconnect` remove, so a killed app or lost signal clears it
  /// server-side. Never throws.
  Future<void> setTyping(String chatId, String uid, bool typing) async {
    if (!supports(chatId)) return;
    final path = _path(chatId, uid);
    try {
      if (typing && _disconnectArmed.add(path)) {
        await _realtime.store.removeOnDisconnect(path);
      }
      await _realtime.store.set(path, {
        'typing': typing,
        'ts': kRealtimeServerTimestamp,
      }).timeout(kRealtimeAckTimeout);
    } catch (e) {
      debugPrint('[ChatTyping] $path → $typing failed: $e');
    }
  }

  /// [peerUid]'s presence in [chatId], as it changes.
  Stream<ChatPresence?> watchPresence(String chatId, String peerUid) {
    if (!supports(chatId)) return const Stream.empty();
    return _realtime.store
        .watch(_path(chatId, peerUid))
        .map(ChatPresence.tryParse);
  }
}
