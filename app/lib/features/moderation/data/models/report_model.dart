import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/report_entity.dart';

class ReportModel extends ReportEntity {
  const ReportModel({
    required super.id,
    required super.reporterId,
    required super.reportedId,
    required super.contentType,
    required super.contentId,
    required super.reason,
    super.additionalDetails,
    required super.createdAt,
    required super.status,
    super.snapshot,
  });

  /// The evidence copy of a reported chat message or forum post, from its
  /// stored fields as read. firestore.rules (`snapshotIsReal`) accepts it only
  /// if it equals the stored document field for field, so `sentAt` must stay
  /// the raw Timestamp, never a DateTime round trip. Null for other types.
  static Map<String, dynamic>? reportSnapshotOf(
    String contentType,
    Map<String, dynamic> doc,
  ) =>
      switch (contentType) {
        'chat' => {
            'text': doc['text'],
            'senderId': doc['senderId'],
            'sentAt': doc['createdAt'],
          },
        'post' => {
            'title': doc['title'],
            'body': doc['body'],
            'imageUrls': doc['imageUrls'] ?? const <String>[],
            'senderId': doc['userId'],
            'sentAt': doc['createdAt'],
          },
        _ => null,
      };

  factory ReportModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ReportModel(
      id: id,
      reporterId: data['reporterId'] ?? '',
      reportedId: data['reportedId'] ?? '',
      contentType: data['contentType'] ?? 'user',
      contentId: data['contentId'] ?? '',
      reason: data['reason'] ?? '',
      additionalDetails: data['additionalDetails'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reportedId': reportedId,
      'contentType': contentType,
      'contentId': contentId,
      'reason': reason,
      if (additionalDetails != null) 'additionalDetails': additionalDetails,
      'createdAt': FieldValue.serverTimestamp(),
      'status': status,
      if (snapshot != null) 'snapshot': snapshot,
    };
  }
}
