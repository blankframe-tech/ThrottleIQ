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
  });

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
    };
  }
}
