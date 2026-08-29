class ReportEntity {
  final String id;
  final String reporterId;
  final String reportedId;
  final String contentType; // 'user', 'ride', 'post', 'comment', 'chat'
  final String contentId;
  final String reason;
  final String? additionalDetails;
  final DateTime createdAt;
  final String status; // 'pending', 'reviewed', 'actioned'

  const ReportEntity({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.contentType,
    required this.contentId,
    required this.reason,
    this.additionalDetails,
    required this.createdAt,
    required this.status,
  });
}
