import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/group_ride_entity.dart';

void main() {
  group('GroupRideMember', () {
    final member = GroupRideMember(
      userId: 'user1',
      userName: 'John Doe',
      userPhotoUrl: 'http://example.com/photo.jpg',
      joinedAt: DateTime.now(),
      status: GroupRideMemberStatus.joined,
      currentLat: 40.7128,
      currentLng: -74.0060,
    );

    test('creates member with all fields', () {
      expect(member.userId, 'user1');
      expect(member.userName, 'John Doe');
      expect(member.status, GroupRideMemberStatus.joined);
    });

    test('member status can be pending', () {
      final pending = GroupRideMember(
        userId: 'user2',
        userName: 'Jane Doe',
        userPhotoUrl: 'http://example.com/photo2.jpg',
        joinedAt: DateTime.now(),
        status: GroupRideMemberStatus.pending,
      );

      expect(pending.status, GroupRideMemberStatus.pending);
      expect(pending.currentLat, null);
    });

    test('member can be declined', () {
      final declined = GroupRideMember(
        userId: 'user3',
        userName: 'Bob Smith',
        userPhotoUrl: 'http://example.com/photo3.jpg',
        joinedAt: DateTime.now(),
        status: GroupRideMemberStatus.declined,
      );

      expect(declined.status, GroupRideMemberStatus.declined);
    });
  });

  group('GroupRideEntity', () {
    final startTime = DateTime.now().add(Duration(hours: 2));
    final members = [
      GroupRideMember(
        userId: 'user1',
        userName: 'Creator',
        userPhotoUrl: 'http://example.com/photo1.jpg',
        joinedAt: DateTime.now(),
        status: GroupRideMemberStatus.joined,
      ),
      GroupRideMember(
        userId: 'user2',
        userName: 'Member 2',
        userPhotoUrl: 'http://example.com/photo2.jpg',
        joinedAt: DateTime.now(),
        status: GroupRideMemberStatus.joined,
      ),
    ];

    final groupRide = GroupRideEntity(
      id: 'groupride1',
      creatorId: 'user1',
      creatorName: 'Creator',
      name: 'Sunday Morning Ride',
      description: 'Easy pace group ride',
      startTime: startTime,
      members: members,
      createdAt: DateTime.now(),
      maxParticipants: 20,
    );

    test('creates group ride with members', () {
      expect(groupRide.id, 'groupride1');
      expect(groupRide.name, 'Sunday Morning Ride');
      expect(groupRide.members.length, 2);
      expect(groupRide.status, GroupRideStatus.planned);
    });

    test('counts joined members correctly', () {
      expect(groupRide.joinedMembersCount, 2);
    });

    test('is not full with members under limit', () {
      expect(groupRide.isFull, false);
    });

    test('is full when at max participants', () {
      final fullMembers = List<GroupRideMember>.generate(
        20,
        (i) => GroupRideMember(
          userId: 'user$i',
          userName: 'User $i',
          userPhotoUrl: 'http://example.com/photo$i.jpg',
          joinedAt: DateTime.now(),
          status: GroupRideMemberStatus.joined,
        ),
      );

      final fullRide = groupRide.copyWith(members: fullMembers);
      expect(fullRide.isFull, true);
    });

    test('copyWith changes status', () {
      final activeRide = groupRide.copyWith(status: GroupRideStatus.active);
      expect(activeRide.status, GroupRideStatus.active);
      expect(activeRide.creatorId, groupRide.creatorId);
    });

    test('can have route reference', () {
      final withRoute = groupRide.copyWith();
      final routedRide = GroupRideEntity(
        id: withRoute.id,
        creatorId: withRoute.creatorId,
        creatorName: withRoute.creatorName,
        name: withRoute.name,
        description: withRoute.description,
        startTime: withRoute.startTime,
        routeId: 'route123',
        members: withRoute.members,
        createdAt: withRoute.createdAt,
        maxParticipants: withRoute.maxParticipants,
      );

      expect(routedRide.routeId, 'route123');
    });

    test('props include id and creator', () {
      expect(groupRide.props, contains(groupRide.id));
      expect(groupRide.props, contains(groupRide.creatorId));
    });
  });
}
