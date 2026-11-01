extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  String get shortDate {
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
  }

  String get shortDateTime {
    return '$shortDate ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

/// The time to show for a ride comment, forum post or reply (issue #157).
/// [createdAt] is the server time it landed; [writtenAt] the phone's time
/// when the rider wrote it, which differs when the write was queued offline
/// or during a quota outage. The phone time wins only within the 48 h before
/// [createdAt], so a wrong phone clock can't push it into the future or far
/// back. A still-pending write (no server time yet) shows [writtenAt].
DateTime displayTime(DateTime? createdAt, DateTime? writtenAt) {
  if (createdAt == null) return writtenAt ?? DateTime.now();
  if (writtenAt == null ||
      writtenAt.isAfter(createdAt) ||
      writtenAt.isBefore(createdAt.subtract(const Duration(hours: 48)))) {
    return createdAt;
  }
  return writtenAt;
}
