import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class ReportRepository {
  static final ReportRepository _instance = ReportRepository._internal();
  factory ReportRepository() => _instance;
  ReportRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReport({
    required String reporterId,
    required String reportedId,
    required String contentType,
    required String contentId,
    required String reason,
    String? additionalDetails,
  }) async {
    final report = ReportModel(
      id: '', // Will be assigned by Firestore
      reporterId: reporterId,
      reportedId: reportedId,
      contentType: contentType,
      contentId: contentId,
      reason: reason,
      additionalDetails: additionalDetails,
      createdAt: DateTime.now(), // Overwritten by serverTimestamp
      status: 'pending',
    );

    await _firestore.collection('reports').add(report.toFirestore());
  }
}
