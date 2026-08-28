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

    test('scalars and timestamps survive write → read', () {
      final read = GroupRideModel.fromFirestore(
        asFirestoreRead(buildModel().toFirestore()),
        'gr1',
      );

      expect(read.id, 'gr1');
      expect(read.creatorId, 'creator');
      expect(read.status, 'active');
      expect(read.startTime, startTime);
      expect(read.createdAt, createdAt);
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
    });

    test(
      'the ride document carries NO members array — the roster is a '
      'subcollection now, and writing it here too would put the array of maps '
      'back inside the parent update surface an accepting invitee can reach',
      () {
        expect(buildModel().toFirestore().containsKey('members'), isFalse);
      },
    );

    test('joinCode survives write → read', () {
      final withCode = GroupRideModel(
        id: 'gr1',
        creatorId: 'creator',
        creatorName: 'Sam',
        name: "Sam's group ride",
        startTime: startTime,
        status: 'active',
        createdAt: createdAt,
        joinCode: 'AB12CD',
      );

      final read = GroupRideModel.fromFirestore(
        asFirestoreRead(withCode.toFirestore()),
        'gr1',
      );

      expect(read.joinCode, 'AB12CD');
      expect(read.toEntity().joinCode, 'AB12CD');
    });

    test('a ride created before joinCode existed reads as an empty code', () {
      final read = GroupRideModel.fromFirestore({
        'creatorId': 'creator',
        'creatorName': 'Sam',
        'name': 'Legacy ride',
        'startTime': Timestamp.fromDate(startTime),
        'createdAt': Timestamp.fromDate(createdAt),
      }, 'legacy');

      expect(read.joinCode, '');
    });
  });

  group('GroupRideMemberModel documents', () {
    GroupRideMemberModel buildMember() => GroupRideMemberModel(
          userId: 'friend1',
          userName: 'Alex',
          userPhotoUrl: 'http://example.com/a.png',
          joinedAt: createdAt,
          status: 'pending',
        );

    test('a member document survives write → read', () {
      final read = GroupRideMemberModel.fromDocument(
        asFirestoreRead(buildMember().toDocument()),
        'friend1',
      );

      expect(read.userId, 'friend1');
      expect(read.userName, 'Alex');
      expect(read.userPhotoUrl, 'http://example.com/a.png');
      expect(read.joinedAt, createdAt);
      expect(read.status, 'pending');
      expect(read.toEntity().status, GroupRideMemberStatus.pending);
    });

    test(
      'the document id wins over the userId field — the id is what the rules '
      'pin the write to, so it is the value that cannot be spoofed',
      () {
        final read = GroupRideMemberModel.fromDocument(
          {...buildMember().toDocument(), 'userId': 'someone-else'},
          'friend1',
        );

        expect(read.userId, 'friend1');
      },
    );

    test('a declined-only merge write (no name, no timestamps) still parses',
        () {
      // declineInvitation writes exactly {'userId', 'status'} with merge, so
      // a member document that never got a name must not throw.
      final read = GroupRideMemberModel.fromDocument(
        const {'userId': 'friend1', 'status': 'declined'},
        'friend1',
      );

      expect(read.userId, 'friend1');
      expect(read.userName, 'Rider');
      expect(read.userPhotoUrl, '');
      expect(read.toEntity().status, GroupRideMemberStatus.declined);
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

    test(
      'a ride created before the roster moved to a subcollection still reads '
      'its inline members array',
      () {
        final read = GroupRideModel.fromFirestore({
          'creatorId': 'creator',
          'creatorName': 'Sam',
          'name': 'Legacy ride',
          'startTime': Timestamp.fromDate(startTime),
          'createdAt': Timestamp.fromDate(createdAt),
          'memberIds': const ['creator'],
          'members': [
            {
              'userId': 'creator',
              'userName': 'Sam',
              'userPhotoUrl': '',
              'joinedAt': Timestamp.fromDate(createdAt),
              'status': 'joined',
            },
          ],
        }, 'legacy');

        expect(read.members.single.userId, 'creator');
        expect(read.toEntity().members.single.userName, 'Sam');
      },
    );
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

  group('VoiceNoteModel round trip', () {
    VoiceNoteModel buildVoiceNote() => VoiceNoteModel(
          id: 'note1',
          senderId: 'friend1',
          senderName: 'Alex',
          senderPhotoUrl: 'http://example.com/a.png',
          audioUrl:
              'https://res.cloudinary.com/vjvcigkt/video/upload/v1/clip.m4a',
          durationMs: 4200,
        );

    test('a voice note document survives write → read', () {
      final written = {...buildVoiceNote().toDocument(), 'createdAt': createdAt};
      final read =
          VoiceNoteModel.fromDocument(asFirestoreRead(written), 'note1');

      expect(read.id, 'note1');
      expect(read.senderId, 'friend1');
      expect(read.senderName, 'Alex');
      expect(read.senderPhotoUrl, 'http://example.com/a.png');
      expect(read.audioUrl,
          'https://res.cloudinary.com/vjvcigkt/video/upload/v1/clip.m4a');
      expect(read.durationMs, 4200);
      expect(read.createdAt, createdAt);
      expect(read.toEntity().senderId, 'friend1');
    });

    test(
      'toDocument never writes createdAt — the repository always supplies '
      "FieldValue.serverTimestamp() itself, which firestore.rules' "
      'create clause requires exactly',
      () {
        expect(buildVoiceNote().toDocument().containsKey('createdAt'), isFalse);
      },
    );

    test(
      'a fresh local write with no server round trip yet reads createdAt as '
      'null, not "now" — the playback queue relies on this to never treat an '
      'unstamped echo as orderable',
      () {
        final read =
            VoiceNoteModel.fromDocument(buildVoiceNote().toDocument(), 'note1');
        expect(read.createdAt, isNull);
      },
    );

    test('a document missing every optional field parses with safe defaults',
        () {
      final read = VoiceNoteModel.fromDocument(const {}, 'note1');

      expect(read.id, 'note1');
      expect(read.senderName, 'Rider');
      expect(read.senderPhotoUrl, '');
      expect(read.audioUrl, '');
      expect(read.durationMs, 0);
      expect(read.createdAt, isNull);
    });
  });
}
