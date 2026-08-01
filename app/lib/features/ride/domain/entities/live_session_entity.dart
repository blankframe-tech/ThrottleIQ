import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum LiveSessionStatus { riding, paused, crash, completed }

class LiveSessionEntity extends Equatable {
  final String token;
  final String uid;
  final String rideId;
  final bool active;
  final double? lastLat;
  final double? lastLng;
  final double speedMs;
  final int batteryPct;
  final LiveSessionStatus status;
  final DateTime updatedAt;
  final DateTime expiresAt;

  const LiveSessionEntity({
    required this.token,
    required this.uid,
    required this.rideId,
    required this.active,
    this.lastLat,
    this.lastLng,
    this.speedMs = 0,
    this.batteryPct = 100,
    this.status = LiveSessionStatus.riding,
    required this.updatedAt,
    required this.expiresAt,
  });

  LiveSessionEntity copyWith({
    String? token,
    String? uid,
    String? rideId,
    bool? active,
    double? lastLat,
    double? lastLng,
    double? speedMs,
    int? batteryPct,
    LiveSessionStatus? status,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return LiveSessionEntity(
      token: token ?? this.token,
      uid: uid ?? this.uid,
      rideId: rideId ?? this.rideId,
      active: active ?? this.active,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      speedMs: speedMs ?? this.speedMs,
      batteryPct: batteryPct ?? this.batteryPct,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'token': token,
      'uid': uid,
      'rideId': rideId,
      'active': active,
      'lastLat': lastLat,
      'lastLng': lastLng,
      'speedMs': speedMs,
      'batteryPct': batteryPct,
      'status': status.toString().split('.').last,
      // Firestore Timestamps, NOT ISO strings.
      //
      // A Firestore TTL policy only acts on a real `Timestamp` field — a
      // document whose expiry is stored as a String is silently ignored and
      // never reaped. These were previously written with toIso8601String(),
      // which meant the planned TTL policy on `expiresAt` would have appeared
      // to apply while deleting nothing, forever.
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory LiveSessionEntity.fromFirestore(Map<String, dynamic> data) {
    return LiveSessionEntity(
      token: data['token'] as String,
      uid: data['uid'] as String,
      rideId: data['rideId'] as String,
      active: data['active'] as bool,
      lastLat: data['lastLat'] as double?,
      lastLng: data['lastLng'] as double?,
      speedMs: (data['speedMs'] as num?)?.toDouble() ?? 0,
      batteryPct: data['batteryPct'] as int? ?? 100,
      status: LiveSessionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => LiveSessionStatus.riding,
      ),
      updatedAt: _dateFrom(data['updatedAt']),
      expiresAt: _dateFrom(data['expiresAt']),
    );
  }

  /// Reads a date that may be a Firestore [Timestamp] (what this app writes
  /// now) or an ISO-8601 String (what it wrote before the TTL fix). Sessions
  /// written by an older build are still readable, so a rider mid-ride during
  /// the upgrade doesn't get a crash on their live link. Falls back to the
  /// epoch rather than throwing on an unexpected shape — a live session with
  /// a garbled timestamp should read as long-expired, not blow up the viewer.
  static DateTime _dateFrom(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is DateTime) return raw;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  List<Object?> get props => [
        token,
        uid,
        rideId,
        active,
        lastLat,
        lastLng,
        speedMs,
        batteryPct,
        status,
        updatedAt,
        expiresAt,
      ];
}
