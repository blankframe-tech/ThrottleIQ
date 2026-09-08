import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/chat/data/models/chat_model.dart';
import 'package:throttleiq/features/chat/domain/entities/chat_entity.dart';

void main() {
  group('ChatModel & ChatEntity Tests', () {
    test('ChatModel.fromFirestore parses correctly with timestamps and participants', () {
      final now = DateTime.now();
      final data = {
        'participants': ['alice', 'bob'],
        'lastMessage': {
          'senderId': 'alice',
          'text': 'Hello!',
        },
        'updatedAt': null,
      };

      final model = ChatModel.fromFirestore(data, 'chat_123');
      expect(model.id, 'chat_123');
      expect(model.participants, ['alice', 'bob']);
      expect(model.lastMessage?['text'], 'Hello!');
      expect(model.updatedAt.isBefore(now.add(const Duration(seconds: 1))), isTrue);
    });

    test('MessageModel.fromFirestore and toFirestore work symmetrically', () {
      final data = {
        'senderId': 'alice',
        'text': 'Hey there!',
        'isRead': false,
      };

      final message = MessageModel.fromFirestore(data, 'msg_1');
      expect(message.id, 'msg_1');
      expect(message.senderId, 'alice');
      expect(message.text, 'Hey there!');
      expect(message.isRead, isFalse);

      final outData = message.toFirestore();
      expect(outData['senderId'], 'alice');
      expect(outData['text'], 'Hey there!');
      expect(outData['isRead'], isFalse);
    });

    test('In-memory chat list sorting puts most recent updatedAt first', () {
      final time1 = DateTime(2026, 9, 1, 10, 0);
      final time2 = DateTime(2026, 9, 1, 12, 0);
      final time3 = DateTime(2026, 9, 1, 8, 0);

      final chat1 = ChatEntity(id: '1', participants: ['u1', 'u2'], updatedAt: time1);
      final chat2 = ChatEntity(id: '2', participants: ['u1', 'u3'], updatedAt: time2);
      final chat3 = ChatEntity(id: '3', participants: ['u1', 'u4'], updatedAt: time3);

      final list = [chat1, chat2, chat3];
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      expect(list.map((c) => c.id).toList(), ['2', '1', '3']);
    });

    test('Unread message filtering correctly identifies messages sent by other participant', () {
      const currentUserId = 'alice';
      final messages = [
        {'id': 'm1', 'senderId': 'bob', 'isRead': false},
        {'id': 'm2', 'senderId': 'alice', 'isRead': false},
        {'id': 'm3', 'senderId': 'bob', 'isRead': false},
      ];

      final toMark = messages.where((m) => m['senderId'] != currentUserId).toList();
      expect(toMark.length, 2);
      expect(toMark.every((m) => m['senderId'] == 'bob'), isTrue);
    });
  });
}
