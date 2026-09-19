import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat_entity.dart';
import '../models/chat_model.dart';

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

  Stream<List<MessageEntity>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

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

  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    // Only mark messages where we are NOT the sender
    final unreadSnap = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    final docsToUpdate = unreadSnap.docs
        .where((doc) => doc.data()['senderId'] != currentUserId)
        .toList();

    if (docsToUpdate.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in docsToUpdate) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
