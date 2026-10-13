import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/chat_typing_channel.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final chatTypingChannelProvider = Provider(
  (ref) => ChatTypingChannel(ref.watch(realtimeServicesProvider)),
);

/// Whether the other rider in a 1:1 chat is typing right now. Always false
/// when RTDB isn't configured or the chat has a legacy (non-DM) id.
///
/// Re-evaluated every second as well as on each change, so "typing…"
/// expires [kTypingExpiry] after the peer's last refresh even if their
/// `false` never arrives. Holds a socket lease while watched.
final peerTypingProvider = StreamProvider.autoDispose
    .family<bool, ({String chatId, String peerUid})>((ref, args) {
  final channel = ref.watch(chatTypingChannelProvider);
  if (!channel.supports(args.chatId)) return Stream.value(false);

  final lease = channel.services.acquire('chat-typing-read');
  final controller = StreamController<bool>();
  ChatPresence? presence;
  var offsetMs = 0;
  void emit() {
    if (controller.isClosed) return;
    controller.add(isPeerTyping(presence,
        localNow: DateTime.now(), serverTimeOffsetMs: offsetMs));
  }

  final presenceSub =
      channel.watchPresence(args.chatId, args.peerUid).listen((p) {
    presence = p;
    emit();
  }, onError: (Object _) {
    presence = null;
    emit();
  });
  final offsetSub =
      channel.services.store.watchServerTimeOffset().listen((o) {
    offsetMs = o;
    emit();
  }, onError: (Object _) {});
  final ticker = Timer.periodic(const Duration(seconds: 1), (_) => emit());
  ref.onDispose(() {
    ticker.cancel();
    presenceSub.cancel();
    offsetSub.cancel();
    controller.close();
    lease.release();
  });
  emit();
  return controller.stream.distinct();
});

final userChatsProvider = StreamProvider.autoDispose<List<ChatEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(chatRepositoryProvider).watchUserChats(user.uid);
});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<MessageEntity>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});

final singleChatProvider = FutureProvider.autoDispose.family<ChatEntity?, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).getChat(chatId);
});

/// Whether messaging [otherUid] is off because either side has blocked the
/// other. firestore.rules already rejects those sends; this lets the room
/// say so up front and disable the input instead of letting the rider type
/// into a permission error.
///
/// A failed "did they block me" lookup reads as not-blocked: the server
/// rule is the real gate, and a flaky read shouldn't lock a rider out of
/// a conversation.
final chatBlockedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, otherUid) async {
  final myUid = ref.watch(currentUserProvider)?.uid;
  if (myUid == null || otherUid.isEmpty) return false;
  final myBlocks = await ref.watch(blockedUsersProvider.future);
  if (myBlocks.contains(otherUid)) return true;
  try {
    return await ref.watch(profileRepositoryProvider).isBlockedBy(otherUid, myUid);
  } catch (_) {
    return false;
  }
});

/// Chats with riders the current user has blocked are hidden from the list.
/// Pure so it can be unit-tested without Firestore.
List<ChatEntity> visibleChats(
  List<ChatEntity> chats, {
  required String? myUid,
  required Set<String> blocked,
}) {
  if (blocked.isEmpty) return chats;
  return chats
      .where((c) => !c.participants.any((id) => id != myUid && blocked.contains(id)))
      .toList();
}

