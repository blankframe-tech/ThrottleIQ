import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/chat_providers.dart';
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';
import '../../../../core/i18n/l10n_context.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String chatId;
  final UserProfileEntity? otherUser;

  const ChatRoomScreen({super.key, required this.chatId, this.otherUser});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final myUid = ref.read(currentUserProvider)?.uid;
        if (myUid != null) {
          await ref.read(chatRepositoryProvider).markMessagesAsRead(widget.chatId, myUid);
        }
      } catch (e) {
        debugPrint('Failed to mark messages as read: $e');
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final myUid = ref.read(currentUserProvider)?.uid;
    if (myUid == null) return;

    _textController.clear();

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        chatId: widget.chatId,
        senderId: myUid,
        text: text,
      );
    } catch (e) {
      if (!mounted) return;
      // Offline sends are queued by Firestore and never land here; a
      // rejected write (e.g. permission-denied after a block) does. Give the
      // rider their words back instead of silently eating them, unless
      // they've already started typing something new.
      if (_textController.text.isEmpty) _textController.text = text;
      if (e is FirebaseException && e.code == 'permission-denied') {
        // Most likely a block the room didn't know about yet; re-check so
        // the banner appears.
        final otherUid = _otherUid;
        if (otherUid != null) ref.invalidate(chatBlockedProvider(otherUid));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mapFirestoreError(e)),
          action: SnackBarAction(
            label: context.l10n.retry,
            onPressed: _sendMessage,
          ),
        ),
      );
    }
  }

  /// The other participant's uid, once known (from the route extra, or the
  /// chat doc for a deep link).
  String? _otherUid;

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final myUid = ref.watch(currentUserProvider)?.uid;
    final chatAsync = ref.watch(singleChatProvider(widget.chatId));
    final fallbackOtherUid = chatAsync.valueOrNull?.participants.firstWhere(
      (id) => id != myUid,
      orElse: () => '',
    );
    final profileLookupUid = widget.otherUser?.uid ?? (fallbackOtherUid?.isNotEmpty == true ? fallbackOtherUid : null);
    final resolvedOtherUser = widget.otherUser ?? (profileLookupUid != null ? ref.watch(profileProvider(profileLookupUid)).valueOrNull : null);
    _otherUid = profileLookupUid;
    final blocked = profileLookupUid != null &&
        (ref.watch(chatBlockedProvider(profileLookupUid)).valueOrNull ?? false);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Row(
          children: [
            UserAvatar(
              photoUrl: resolvedOtherUser?.photoUrl,
              name: resolvedOtherUser?.bestName ?? context.l10n.riderFallbackName,
              radius: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                resolvedOtherUser?.bestName ?? context.l10n.chat,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                error: e,
                showBugReport: true,
                onRetry: () => ref.invalidate(chatMessagesProvider(widget.chatId)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(child: Text(context.l10n.sayHi, style: TextStyle(color: context.palette.textSecondary)));
                }
                
                return ListView.builder(
                  reverse: true, // Show bottom to top
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myUid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMe ? null : () {
                          ReportBottomSheet.show(
                            context,
                            reportedId: msg.senderId,
                            contentType: 'chat',
                            contentId: msg.id,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? context.palette.primary : context.palette.surface,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                            ),
                            border: isMe ? null : Border.all(color: context.palette.border),
                          ),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : context.palette.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.jm().format(msg.createdAt),
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : context.palette.textTertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (blocked)
            Container(
              key: const Key('chat-blocked-banner'),
              width: double.infinity,
              padding: EdgeInsets.only(
                left: AppDimensions.paddingMd,
                right: AppDimensions.paddingMd,
                top: 14,
                bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 14,
              ),
              decoration: BoxDecoration(
                color: context.palette.surface,
                border: Border(top: BorderSide(color: context.palette.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, size: 18, color: context.palette.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.cantMessageThisRider,
                      style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else
          Container(
            padding: EdgeInsets.only(
              left: AppDimensions.paddingMd,
              right: AppDimensions.paddingMd,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 12,
            ),
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border(top: BorderSide(color: context.palette.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: context.palette.textPrimary),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: context.l10n.messageHint,
                      hintStyle: TextStyle(color: context.palette.textTertiary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: context.palette.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: context.palette.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: context.l10n.send,
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
