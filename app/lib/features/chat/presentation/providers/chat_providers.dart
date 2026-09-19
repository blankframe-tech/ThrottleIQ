import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

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

