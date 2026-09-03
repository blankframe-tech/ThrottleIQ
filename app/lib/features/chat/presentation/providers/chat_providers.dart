import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

