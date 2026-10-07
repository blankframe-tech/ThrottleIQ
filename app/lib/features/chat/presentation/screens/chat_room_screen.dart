import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/realtime/realtime_connection_manager.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/typing_indicator_controller.dart';
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

  /// Debounces keystrokes into RTDB typing-state writes. Null when typing
  /// indicators aren't available for this chat (no RTDB, legacy chat id).
  TypingIndicatorController? _typing;
  RealtimeLease? _typingLease;

  /// Set from build: no "typing…" goes to someone the rider can't message.
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    final channel = ref.read(chatTypingChannelProvider);
    final myUid = ref.read(currentUserProvider)?.uid;
    if (myUid != null && channel.supports(widget.chatId)) {
      _typingLease = channel.services.acquire('chat-typing-write');
      _typing = TypingIndicatorController(
        send: (typing) {
          if (typing && _blocked) return;
          unawaited(channel.setTyping(widget.chatId, myUid, typing));
        },
      );
    }
  }

  // -- Older messages (issues §90.A8) -------------------------------------
  // The live stream only carries the newest kChatMessagesPageSize messages.
  // Once the rider pages back, every message seen (live or fetched) is kept
  // in [_pinned], so a new arrival pushing one out of the live window can't
  // open a gap between the live window and the older pages.
  final Map<String, MessageEntity> _pinned = {};
  bool _pagingStarted = false;
  bool _loadingOlder = false;
  bool _hasOlder = true;

  List<MessageEntity> _displayed(List<MessageEntity> live) {
    if (!_pagingStarted) return live;
    for (final m in live) {
      _pinned[m.id] = m;
    }
    return _pinned.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _loadOlder(List<MessageEntity> shown) async {
    if (_loadingOlder || shown.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .fetchOlderMessages(widget.chatId, before: shown.last.createdAt);
      if (!mounted) return;
      setState(() {
        if (!_pagingStarted) {
          for (final m in shown) {
            _pinned[m.id] = m;
          }
          _pagingStarted = true;
        }
        for (final m in page) {
          _pinned[m.id] = m;
        }
        _hasOlder = page.length >= kChatMessagesPageSize;
        _loadingOlder = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOlder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirestoreError(e, context.l10n))),
      );
    }
  }

  @override
  void dispose() {
    _typing?.dispose();
    _typingLease?.release();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final myUid = ref.read(currentUserProvider)?.uid;
    if (myUid == null) return;

    _textController.clear();
    _typing?.onSent();

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
          content: Text(mapFirestoreError(e, context.l10n)),
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
    _blocked = blocked;
    final peerTyping = profileLookupUid != null &&
        !blocked &&
        (ref
                .watch(peerTypingProvider(
                    (chatId: widget.chatId, peerUid: profileLookupUid)))
                .valueOrNull ??
            false);

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resolvedOtherUser?.bestName ?? context.l10n.chat,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (peerTyping)
                    Text(
                      context.l10n.chatTyping,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: context.palette.textSecondary,
                      ),
                    ),
                ],
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
              data: (live) {
                final messages = _displayed(live);
                if (messages.isEmpty) {
                  return Center(child: Text(context.l10n.sayHi, style: TextStyle(color: context.palette.textSecondary)));
                }
                final showLoadOlder = _pagingStarted
                    ? _hasOlder
                    : live.length >= kChatMessagesPageSize;

                return ListView.builder(
                  reverse: true, // Show bottom to top
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: 8),
                  itemCount: messages.length + (showLoadOlder ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      // Last index of a reversed list = the top of the room.
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: _loadingOlder
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: context.palette.primary),
                                )
                              : TextButton(
                                  onPressed: () => _loadOlder(messages),
                                  child: Text(context.l10n.loadOlderMessages),
                                ),
                        ),
                      );
                    }
                    final msg = messages[index];
                    final isMe = msg.senderId == myUid;

                    // issues §101.A4: own bubbles sit on palette.primary, where
                    // white text was 1.18:1 on sport/dark lime.
                    final ownFg = AppTheme.primaryButtonForeground(context.palette);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      // Tells a screen reader the long press reports the message.
                      child: Semantics(
                        onLongPressHint: isMe ? null : context.l10n.report,
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
                                    color: isMe ? ownFg : context.palette.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.jm().format(msg.createdAt),
                                  style: TextStyle(
                                    color: isMe ? ownFg.withValues(alpha: 0.75) : context.palette.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
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
                    onChanged: _typing?.onTextChanged,
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
