import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(userChatsProvider);
    final myUid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: chatsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text('No messages yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            itemCount: chats.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.border),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUserId = chat.participants.firstWhere((id) => id != myUid, orElse: () => '');
              if (otherUserId.isEmpty) return const SizedBox.shrink();

              final otherProfileAsync = ref.watch(profileProvider(otherUserId));
              
              return otherProfileAsync.when(
                loading: () => const ListTile(title: Text('Loading...')),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) {
                  if (profile == null) return const SizedBox.shrink();

                  final lastMsg = chat.lastMessage;
                  String subtitle = 'Say hi!';

                  if (lastMsg != null) {
                    subtitle = lastMsg['text'] ?? '';
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(photoUrl: profile.photoUrl, name: profile.bestName, radius: 24),
                    title: Text(profile.bestName, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: Text(
                      DateFormat.MMMd().format(chat.updatedAt),
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    onTap: () => context.push('/chats/${chat.id}', extra: profile),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
