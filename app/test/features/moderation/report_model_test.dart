import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/moderation/data/models/report_model.dart';

// The rules accept a snapshot only if it equals the stored message field for
// field (scripts/test/rules/report_snapshot_rules.test.js), so the shape and
// the raw Timestamp matter.
void main() {
  ReportModel report({Map<String, dynamic>? snapshot}) => ReportModel(
        id: '',
        reporterId: 'bob',
        reportedId: 'mallory',
        contentType: 'chat',
        contentId: 'chats/a_m/messages/m1',
        reason: 'Harassment or bullying',
        createdAt: DateTime(2026),
        status: 'pending',
        snapshot: snapshot,
      );

  test('reportSnapshotOf copies text, sender and the raw sent Timestamp', () {
    final sent = Timestamp(1790000000, 123456000);
    final snap = ReportModel.reportSnapshotOf({
      'senderId': 'mallory',
      'text': 'you idiot',
      'createdAt': sent,
      'isRead': false,
      'isToxic': true,
    });
    expect(snap, {'text': 'you idiot', 'senderId': 'mallory', 'sentAt': sent});
    expect(identical(snap['sentAt'], sent), isTrue);
    expect(report(snapshot: snap).toFirestore()['snapshot'], snap);
  });

  test('a report without a snapshot sends no snapshot key', () {
    expect(report().toFirestore().containsKey('snapshot'), isFalse);
  });
}
