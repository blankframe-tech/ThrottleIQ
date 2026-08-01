import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/data/models/group_ride_model.dart';
import 'package:throttleiq/features/social/domain/entities/group_ride_entity.dart';

void main() {
  final createdAt = DateTime(2026, 3, 4, 10, 30);
  final startTime = DateTime(2026, 3, 4, 10, 31);

  GroupRideModel buildModel() => GroupRideModel(
        id: 'gr1',
        creatorId: 'creator',
        creatorName: 'Sam',
        name: "Sam's group ride",
        startTime: startTime,
        status: 'active',
        members: [
          GroupRideMemberModel(
            userId: 'creator',
            userName: 'Sam',
            userPhotoUrl: '',
            joinedAt: createdAt,
            status: 'joined',
          ),
          GroupRideMemberModel(
            userId: 'friend1',
            userName: 'Alex',
            userPhotoUrl: 'http://example.com/a.png',
            joinedAt: createdAt,
            status: 'pending',
          ),
        ],
        memberIds: const ['creator'],
        invitedIds: const ['friend1'],
        createdAt: createdAt,
        maxParticipants: 3,
      );

  /// Firestore hands DateTimes back as Timestamps, so a real round trip has
  /// to go through that conversion — writing the map straight back in would
  /// test a code path the app never takes.
  Map<String, dynamic> asFirestoreRead(Map<String, dynamic> written) {
    Object? convert(Object? value) {
      if (value is DateTime) return Timestamp.fromDate(value);
      if (value is List) return value.map(convert).toList();
      if (value is Map) {
        return value.map((k, v) => MapEntry(k as String, convert(v)));
      }
      return value;
    }

    return convert(written)! as Map<String, dynamic>;
  }

  group('GroupRideModel round trip', () {
    test('memberIds and invitedIds survive write → read', () {
      final read = GroupRideModel.fromFirestore(
        asFirestoreRead(buildModel().toFirestore()),
        'gr1',
      );

      expect(read.memberIds, ['creator']);
      expect(read.invitedIds, ['friend1']);
    });

    test('roster, statuses and timestamps survive write → read', () {
      final read = GroupRideModel.fromFirestore(
        asFirestoreRead(buildModel().toFirestore()),
        'gr1',
      );

      expect(read.id, 'gr1');
      expect(read.creatorId, 'creator');
      expect(read.status, 'active');
      expect(read.startTime, startTime);
      expect(read.createdAt, createdAt);
      expect(read.members.map((m) => m.userId), ['creator', 'friend1']);
      expect(read.members.map((m) => m.status), ['joined', 'pending']);
      expect(read.maxParticipants, 3);
    });

    test('entity conversion carries the membership arrays through', () {
      final entity = GroupRideModel.fromFirestore(
        asFirestoreRead(buildModel().toFirestore()),
        'gr1',
      ).toEntity();

      expect(entity.memberIds, ['creator']);
      expect(entity.invitedIds, ['friend1']);
      expect(entity.status, GroupRideStatus.active);
      expect(entity.members.last.status, GroupRideMemberStatus.pending);
      expect(entity.joinedMembersCount, 1);
    });
  });

  group('GroupRideModel tolerates partial documents', () {
    test('a member with a null avatar and null timestamps parses', () {
      final member = GroupRideMemberModel.fromFirestore(const {
        'userId': 'u1',
        'userName': 'Jo',
        'userPhotoUrl': null,
        'joinedAt': null,
        'status': 'joined',
        'currentLat': null,
        'currentLng': null,
        'lastLocationUpdate': null,
      });

      expect(member.userPhotoUrl, '');
      expect(member.lastLocationUpdate, isNull);
      expect(member.currentLat, isNull);
    });

    test('a document written before memberIds existed reads as empty lists', () {
      final read = GroupRideModel.fromFirestore({
        'creatorId': 'creator',
        'creatorName': 'Sam',
        'name': 'Legacy ride',
        'startTime': Timestamp.fromDate(startTime),
        'createdAt': Timestamp.fromDate(createdAt),
        'members': const <dynamic>[],
      }, 'legacy');

      expect(read.memberIds, isEmpty);
      expect(read.invitedIds, isEmpty);
      expect(read.members, isEmpty);
    });
  });

  group('GroupRideEntity.joinedMembers ordering', () {
    test('is sorted by uid so marker colours stay put', () {
      final entity = GroupRideEntity(
        id: 'gr1',
        creatorId: 'zeta',
        creatorName: 'Zeta',
        name: 'ride',
        startTime: startTime,
        createdAt: createdAt,
        members: [
          GroupRideMember(
              userId: 'zeta',
              userName: 'Zeta',
              userPhotoUrl: '',
              joinedAt: createdAt),
          GroupRideMember(
              userId: 'alpha',
              userName: 'Alpha',
              userPhotoUrl: '',
              joinedAt: createdAt),
          GroupRideMember(
            userId: 'mid',
            userName: 'Mid',
            userPhotoUrl: '',
            joinedAt: createdAt,
            status: GroupRideMemberStatus.pending,
          ),
        ],
      );

      expect(entity.joinedMembers.map((m) => m.userId), ['alpha', 'zeta']);
    });
  });
}
