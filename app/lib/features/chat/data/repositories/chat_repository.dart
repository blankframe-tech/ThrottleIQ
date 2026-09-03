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

  Future<String> getOrCreateChat(String currentUserId, String otherUserId) async {
    // Check if chat exists
    final snap = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in snap.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Create new chat
    final newChatRef = await _firestore.collection('chats').add({
      'participants': [currentUserId, otherUserId],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return newChatRef.id;
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
