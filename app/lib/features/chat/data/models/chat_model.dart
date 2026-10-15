import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat_entity.dart';

class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.participants,
    super.lastMessage,
    required super.updatedAt,
    super.participantNames,
    super.participantPhotos,
  });

  factory ChatModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatModel(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantNames: data['participantNames'] != null 
          ? Map<String, String>.from(data['participantNames']) 
          : null,
      participantPhotos: data['participantPhotos'] != null 
          ? Map<String, String>.from(data['participantPhotos']) 
          : null,
    );
  }
}

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.senderId,
    required super.text,
    required super.createdAt,
    super.isRead,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }
}
