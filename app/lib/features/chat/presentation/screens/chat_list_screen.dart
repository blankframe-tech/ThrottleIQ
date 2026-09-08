import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  void _showNewChatModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) => const _NewChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(userChatsProvider);
    final myUid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New message',
            onPressed: () => _showNewChatModal(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewChatModal(context, ref),
        icon: const Icon(Icons.edit, color: Colors.white, size: 20),
        label: const Text('New Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
      ),
      body: chatsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppColors.danger))),
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
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showNewChatModal(context, ref),
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Start a Conversation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
                      ),
                    ),
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

class _NewChatSheet extends ConsumerStatefulWidget {
  const _NewChatSheet();

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  final _searchController = TextEditingController();
  List<UserProfileEntity> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final repo = ref.read(profileRepositoryProvider);
      final myUid = ref.read(currentUserProvider)?.uid;
      final looksLikeEmail = q.contains('@') && q.contains('.') && !q.startsWith('@');
      final list = looksLikeEmail
          ? await repo.searchByEmail(q)
          : await repo.searchByUsername(q);

      if (mounted) {
        setState(() {
          _results = list.where((u) => u.uid != myUid).toList();
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _searching = false;
        });
      }
    }
  }

  Future<void> _startChat(UserProfileEntity rider) async {
    final myUid = ref.read(currentUserProvider)?.uid;
    if (myUid == null) return;

    try {
      final chatId = await ref.read(chatRepositoryProvider).getOrCreateChat(myUid, rider.uid);
      if (mounted) {
        Navigator.pop(context);
        context.push('/chats/$chatId', extra: rider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: AppDimensions.paddingMd,
      ),
      child: SizedBox(
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'New Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search rider by @username or email...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (val) => _performSearch(val),
            ),
            const SizedBox(height: 12),
            if (_searching)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_error != null)
              Center(child: Text('Search failed: $_error', style: TextStyle(color: AppColors.danger)))
            else if (_results.isEmpty && _searchController.text.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No riders found for "${_searchController.text}"',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, index) {
                    final rider = _results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(photoUrl: rider.photoUrl, name: rider.bestName, radius: 20),
                      title: Text(rider.bestName, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      subtitle: rider.username != null
                          ? Text('@${rider.username}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
                          : null,
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                      onTap: () => _startChat(rider),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
