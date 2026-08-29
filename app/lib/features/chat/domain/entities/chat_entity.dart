class ChatEntity {
  final String id;
  final List<String> participants;
  final Map<String, dynamic>? lastMessage;
  final DateTime updatedAt;
  final Map<String, String>? participantNames;
  final Map<String, String>? participantPhotos;

  const ChatEntity({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.updatedAt,
    this.participantNames,
    this.participantPhotos,
  });
}

class MessageEntity {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });
}
