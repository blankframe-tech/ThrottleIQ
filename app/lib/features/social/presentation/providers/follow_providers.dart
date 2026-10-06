import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/follow_repository.dart';
import '../../domain/utilities/follow_suggestions.dart';
import 'notification_providers.dart';

final followRepositoryProvider =
    Provider<FollowRepository>((ref) => FollowRepository());

/// Uids the signed-in rider follows — live, and the ONE follow-graph
/// listener the app keeps open (issues §90.A3/A6). Everything else that
/// needs "do I follow X" derives from it instead of opening its own query:
/// [isFollowingProvider], [mutualIdsProvider], the People tab's Following
/// list, the feed's followed-authors sources and the Following chip.
///
/// This used to be a one-shot `FutureProvider` that was never invalidated by
/// follow/unfollow, so a rider followed mid-session never reached the feed
/// (or the Following list) until the app was restarted.
final followingUidsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return ref
      .watch(followRepositoryProvider)
      .watchFollowing(uid)
      .map((ids) => ids.toSet());
});

/// The followed riders who follow the signed-in rider back (mutuals).
///
/// Derived from [followingUidsProvider], so it recomputes after a
/// follow/unfollow, and costs one read per matching edge (min one per
/// 30-uid chunk) rather than the signed-in rider's whole follower list. The
/// feed reads it to decide which authors' `mutual` rides it may ask for, and
/// invalidates it on pull-to-refresh to pick up riders who followed back.
final mutualIdsProvider = FutureProvider<Set<String>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const <String>{};
  final following = await ref.watch(followingUidsProvider.future);
  if (following.isEmpty) return const <String>{};
  return ref.watch(followRepositoryProvider).getFollowersAmong(uid, following);
});

/// Whether the signed-in rider follows [uid] — derived from
/// [followingUidsProvider], so it costs zero extra reads and zero extra
/// listeners (issues §90.A6: this was a non-autoDispose per-uid document
/// listener, and All People alone left 100 of them open for the session).
final isFollowingProvider =
    Provider.autoDispose.family<AsyncValue<bool>, String>((ref, uid) {
  return ref.watch(followingUidsProvider).whenData((ids) => ids.contains(uid));
});

/// autoDispose so a profile re-opened later re-counts, and
/// [FollowController] invalidates both sides after a follow/unfollow
/// (issues §90.A10).
final followerCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) {
  return ref.watch(followRepositoryProvider).followerCount(uid);
});

final followingCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) {
  return ref.watch(followRepositoryProvider).followingCount(uid);
});

/// How long a computed suggestion list is reused before it's rebuilt.
const Duration kSuggestionsTtl = Duration(minutes: 10);

/// "Suggested for you": followers you don't follow back, then recently
/// joined riders — at most [kSuggestionCap], never someone blocked.
///
/// Bounded and cached (issues §90.A5). It used to read every follower AND
/// following edge, fetch every not-followed-back follower's profile, then
/// 50 more users — and, being plain autoDispose under a `TabBarView`, did it
/// all again on every visit to the People tab. Now: ≤30 follower edges, ≤10
/// profiles, ≤20 recent users, kept alive for [kSuggestionsTtl].
///
/// The follow set is read once rather than watched, so following a
/// suggested rider doesn't rebuild (and re-bill) the whole list; the People
/// tab hides already-followed riders from it live instead.
final suggestedProfilesProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const [];

  final link = ref.keepAlive();
  final ttl = Timer(kSuggestionsTtl, link.close);
  ref.onDispose(ttl.cancel);

  final followRepo = ref.read(followRepositoryProvider);
  final profileRepo = ref.read(profileRepositoryProvider);

  final following = await ref.read(followingUidsProvider.future);
  Set<String> blocked;
  try {
    blocked = await ref.read(blockedUsersProvider.future);
  } catch (_) {
    blocked = const <String>{};
  }

  final followers = await followRepo.getFollowersSample(uid,
      limit: kSuggestionFollowerSample);
  final candidates = followBackCandidates(
    myUid: uid,
    followers: followers,
    following: following,
    blocked: blocked,
  );
  // One unreadable profile (private/mutual visibility) mustn't sink the rest.
  final followBack = (await Future.wait(candidates.map((c) async {
    try {
      return await profileRepo.getProfile(c);
    } catch (_) {
      return null;
    }
  })))
      .whereType<UserProfileEntity>()
      .toList();

  var recent = const <UserProfileEntity>[];
  if (followBack.length < kSuggestionCap) {
    try {
      recent =
          await profileRepo.getRecentUsers(limit: kSuggestionRecentUsersLimit);
    } catch (_) {
      // The follow-back half is still worth showing on its own.
    }
  }

  return mergeSuggestions(
    myUid: uid,
    followBack: followBack,
    recent: recent,
    following: following,
    blocked: blocked,
  );
});

/// Follow / unfollow with the bookkeeping every follow button needs
/// (issues §90.A9/A10): the notification is sent only after the follow is
/// actually written, under a deterministic id so re-follows and double taps
/// can't stack duplicates, and both riders' counts are re-fetched.
final followControllerProvider =
    Provider<FollowController>((ref) => FollowController(ref));

class FollowController {
  FollowController(this._ref);

  final Ref _ref;

  /// How long a button waits for the server to acknowledge the write.
  /// Offline, Firestore queues the write and its future doesn't complete
  /// until reconnect — the local cache (and so [followingUidsProvider])
  /// already reflects it, so the button stops waiting rather than spinning
  /// until the rider is back online.
  static const Duration ackTimeout = Duration(seconds: 8);

  /// Follows ([follow] true) or unfollows [targetUid]. Throws if the write
  /// is rejected; returns normally once it's acknowledged or queued offline.
  /// [fallbackName] is the notification's sender name when the rider's own
  /// profile hasn't loaded (a localized "A rider").
  Future<void> setFollowing(
    String targetUid, {
    required bool follow,
    required String fallbackName,
  }) async {
    final myUid = _ref.read(currentUserProvider)?.uid;
    if (myUid == null || myUid == targetUid) return;
    final repo = _ref.read(followRepositoryProvider);

    final write = follow
        ? repo.follow(myUid, targetUid)
        : repo.unfollow(myUid, targetUid);

    if (follow) {
      // Chained to the write itself, not to the timeout below: an offline
      // follow still notifies once it actually lands, and a rejected one
      // never does.
      unawaited(write
          .then((_) => _notifyFollow(myUid, targetUid, fallbackName))
          .catchError((Object e) {
        debugPrint('Follow notification skipped: $e');
      }));
    }

    try {
      await write.timeout(ackTimeout);
    } on TimeoutException {
      // Queued offline — see [ackTimeout].
    } finally {
      _ref.invalidate(followerCountProvider(targetUid));
      _ref.invalidate(followingCountProvider(myUid));
    }
  }

  Future<void> _notifyFollow(
      String myUid, String targetUid, String fallbackName) {
    final me = _ref.read(myProfileProvider).valueOrNull;
    return _ref.read(notificationRepositoryProvider).notifyFollow(
          toUid: targetUid,
          fromUid: myUid,
          fromName: me?.bestName ?? fallbackName,
          fromPhotoUrl: me?.photoUrl,
        );
  }
}
