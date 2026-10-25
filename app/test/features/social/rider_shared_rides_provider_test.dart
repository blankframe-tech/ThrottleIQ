import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/social/data/repositories/follow_repository.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/presentation/providers/follow_providers.dart';
import 'package:throttleiq/features/social/presentation/providers/ride_feed_provider.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
}

SharedRideEntity _ride(String id, String audience, int day) => SharedRideEntity(
      id: id,
      userId: 'author',
      userName: 'Author',
      userPhotoUrl: '',
      bikeId: 'bike',
      bikeName: 'FZ-S',
      bikeType: 'commuter',
      rideDate: DateTime(2026, 9, day),
      distanceKm: 10,
      durationSeconds: 600,
      maxSpeedKmh: 60,
      polyline: const [],
      createdAt: DateTime(2026, 9, day),
      audience: audience,
    );

/// Records which queries ran; answers each with the author's rides of the
/// audiences it asked for.
class _FakeRides extends Fake implements RideShareRepository {
  final calls = <String>[];
  final all = [
    _ride('pub', 'public', 1),
    _ride('fol', 'followers', 3),
    _ride('mut', 'mutual', 2),
  ];

  @override
  Future<List<SharedRideEntity>> getMyRides(String uid,
      {int limit = 20, DateTime? before, bool hydrateVotes = true}) async {
    calls.add('mine:$uid');
    return all;
  }

  @override
  Future<List<List<SharedRideEntity>>> getPublicRidesByAuthorChunks(
      List<List<String>> authorChunks,
      {int limit = 20,
      DateTime? before}) async {
    calls.add('public:${authorChunks.single.single}');
    return [all.where((r) => r.audience == 'public').toList()];
  }

  @override
  Future<List<SharedRideEntity>> getRestrictedRidesByAuthor(String author,
      {required List<String> audiences,
      int limit = 5,
      DateTime? before}) async {
    calls.add('restricted:$author:${audiences.join(',')}');
    return all.where((r) => audiences.contains(r.audience)).toList();
  }

  @override
  Future<List<SharedRideEntity>> hydrateVotesFor(
          List<SharedRideEntity> rides) async =>
      rides;
}

class _FakeFollows extends Fake implements FollowRepository {
  _FakeFollows(this.followsMe);
  final Set<String> followsMe;

  @override
  Future<Set<String>> getFollowersAmong(
          String uid, Iterable<String> candidates) async =>
      candidates.where(followsMe.contains).toSet();
}

void main() {
  Future<(List<String>, List<String>)> load(String author,
      {Set<String> following = const {},
      Set<String> followsMe = const {}}) async {
    final rides = _FakeRides();
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(_FakeUser()),
      rideShareRepositoryProvider.overrideWithValue(rides),
      followRepositoryProvider.overrideWithValue(_FakeFollows(followsMe)),
      followingUidsProvider.overrideWith((ref) => Stream.value(following)),
    ]);
    addTearDown(container.dispose);
    final result =
        await container.read(riderSharedRidesProvider(author).future);
    return ([for (final r in result) r.id], rides.calls);
  }

  test('own profile lists every audience', () async {
    final (ids, calls) = await load('me');
    expect(ids, ['pub', 'fol', 'mut']);
    expect(calls, ['mine:me']);
  });

  test("a rider you don't follow: public only, no restricted query", () async {
    final (ids, calls) = await load('author');
    expect(ids, ['pub']);
    expect(calls, ['public:author']);
  });

  test('a rider you follow: public + followers, never mutual', () async {
    final (ids, calls) = await load('author', following: {'author'});
    expect(ids, ['fol', 'pub']); // newest first
    expect(calls, contains('restricted:author:followers'));
  });

  test('a mutual: public + followers + mutual, newest first', () async {
    final (ids, calls) =
        await load('author', following: {'author'}, followsMe: {'author'});
    expect(ids, ['fol', 'mut', 'pub']);
    expect(calls, contains('restricted:author:followers,mutual'));
  });
}
