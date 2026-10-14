import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_positions.dart';

/// A group-ride member's marker position, from Firestore only (the RTDB
/// channel was parked on branch park/rtdb-group-ride on 2026-10-14).
void main() {
  final t = DateTime.utc(2026, 10, 7, 9);
  Map<String, dynamic> fs(DateTime? at) => {
        'lat': 1.0,
        'lng': 1.0,
        'timestamp': at == null ? null : Timestamp.fromDate(at),
      };

  test('the memberLocations doc wins, timed by its timestamp', () {
    final p = freshestMemberPosition(
      firestore: fs(t),
      rosterLat: 3,
      rosterLng: 3,
    )!;
    expect(p.source, MemberPositionSource.firestore);
    expect(p.position.latitude, 1);
    expect(p.updatedAt!.isAtSameMomentAs(t), isTrue);
  });

  test('in-flight Firestore write (null ts) falls back to the roster time', () {
    final p = freshestMemberPosition(firestore: fs(null), rosterUpdatedAt: t)!;
    expect(p.updatedAt, t);
    expect(p.source, MemberPositionSource.firestore);
  });

  test('roster coordinates are the last resort; nothing at all is null', () {
    expect(
      freshestMemberPosition(rosterLat: 3, rosterLng: 3)!.source,
      MemberPositionSource.roster,
    );
    expect(
      freshestMemberPosition(),
      isNull,
      reason: 'never published → off the map, not at 0,0',
    );
  });
}
