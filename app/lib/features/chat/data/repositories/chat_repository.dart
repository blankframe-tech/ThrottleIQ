import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat_entity.dart';
import '../models/chat_model.dart';

/// Messages per page in a chat room (live window and each "load older").
const int kChatMessagesPageSize = 50;

class ChatRepository {
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ChatEntity>> watchUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final chats = snap.docs
          .map((doc) => ChatModel.fromFirestore(doc.data(), doc.id))
          .toList();
      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return chats;
    });
  }

  /// Live view of the newest [limit] messages, newest first (the room's
  /// list is `reverse: true`). Bounded (issues §90.A8): this used to stream
  /// a conversation's entire history on every room open. Earlier messages
  /// come from [fetchOlderMessages].
  Stream<List<MessageEntity>> watchMessages(
    String chatId, {
    int limit = kChatMessagesPageSize,
  }) {
    return _messages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// One page of messages older than [before], newest first — the "load
  /// older" step behind [watchMessages]' live window.
  Future<List<MessageEntity>> fetchOlderMessages(
    String chatId, {
    required DateTime before,
    int limit = kChatMessagesPageSize,
  }) async {
    final snap = await _messages(chatId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs
        .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _firestore.collection('chats').doc(chatId).collection('messages');

  Future<ChatEntity?> getChat(String chatId) async {
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ChatModel.fromFirestore(doc.data()!, doc.id);
  }

  /// The deterministic id of the 1:1 chat between [a] and [b]: both uids,
  /// sorted, joined with `_`. Order-independent, so both riders land on the
  /// same document no matter who opens the chat first.
  /// `firestore.rules` requires new chats to use exactly this id, with
  /// `participants` stored in the same sorted order.
  static String dmId(String a, String b) =>
      (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

  /// Returns the chat between the two riders, creating it if needed.
  ///
  /// This used to scan every chat the caller was in (O(N) reads per open)
  /// and then `add()` a random-id doc, so two riders tapping "Message" at
  /// the same moment each created their own room. Chats now live at
  /// [dmId] and are created inside a transaction, so concurrent opens
  /// converge on one document.
  Future<String> getOrCreateChat(String currentUserId, String otherUserId) async {
    if (currentUserId == otherUserId) {
      throw ArgumentError.value(otherUserId, 'otherUserId', 'cannot chat with yourself');
    }
    final id = dmId(currentUserId, otherUserId);
    final ref = _firestore.collection('chats').doc(id);

    final existing = await ref.get();
    if (existing.exists) return id;

    // Legacy fallback: chats created before deterministic ids have random
    // ids. Check for one once, before creating the deterministic room, so an
    // existing conversation isn't split in two. Remove after a release or
    // two, once those rooms have aged out.
    final legacyId = await _findLegacyChat(currentUserId, otherUserId);
    if (legacyId != null) return legacyId;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'participants': [currentUserId, otherUserId]..sort(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    return id;
  }

  Future<String?> _findLegacyChat(String currentUserId, String otherUserId) async {
    final snap = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();
    for (final doc in snap.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.length == 2 && participants.contains(otherUserId)) {
        return doc.id;
      }
    }
    return null;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final batch = _firestore.batch();
    
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
        
    final chatRef = _firestore.collection('chats').doc(chatId);

    batch.set(messageRef, {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    batch.update(chatRef, {
      'lastMessage': {
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // markMessagesAsRead was removed (issues §90.A12c): it wrote one update
  // per unread message on every room open for an `isRead` flag nothing in
  // the app displays. New messages still carry `isRead: false` so a future
  // read-receipt feature has a field to build on.
}
