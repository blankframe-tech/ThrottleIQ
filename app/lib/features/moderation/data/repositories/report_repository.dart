import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/error_reporter.dart';
import '../models/report_model.dart';

class ReportRepository {
  static ReportRepository _instance = ReportRepository._internal();

  @visibleForTesting
  static set instanceForTest(ReportRepository fake) => _instance = fake;

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
    // Chat reports keep a copy of the message as evidence (owner decision
    // 2026-10-21). Read fresh so the rules' equality check sees the stored
    // Timestamp. Without it the report still goes: a report beats none.
    Map<String, dynamic>? snapshot;
    if (contentType == 'chat' && contentId.startsWith('chats/')) {
      try {
        final message = (await _firestore.doc(contentId).get()).data();
        if (message != null) snapshot = ReportModel.reportSnapshotOf(message);
      } catch (e, st) {
        reportNonFatal(e, st, reason: 'report snapshot read');
      }
    }

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
      snapshot: snapshot,
    );

    final data = report.toFirestore();
    try {
      await _firestore.collection('reports').add(data);
    } on FirebaseException catch (e) {
      // Rules deployed before 2026-10-21 refuse the `snapshot` key, and the
      // message may have changed since it was read: file it without the copy.
      if (e.code != 'permission-denied' || snapshot == null) rethrow;
      reportNonFatal(e, StackTrace.current, reason: 'report snapshot refused');
      await _firestore.collection('reports').add(data..remove('snapshot'));
    }
  }
}
