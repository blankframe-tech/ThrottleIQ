import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/follow_link_store.dart';
import '../../domain/utilities/follow_link.dart';
import '../../domain/utilities/follow_link_outcome.dart';
import 'follow_providers.dart';

final followLinkStoreProvider =
    Provider<FollowLinkStore>((ref) => const FollowLinkStore());

/// Where a successful (or already-done) link follow lands: the Social
/// screen's People tab, which lists who the rider follows.
const String kFollowLinkLandingRoute = '/home/social?tab=people';

/// The signed-in rider's own follow link. Read from the device first; built
/// and saved only the first time, so the QR is identical every time it's
/// opened and shows without any network round-trip.
final myFollowLinkProvider = FutureProvider.autoDispose<String?>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return null;
  final store = ref.watch(followLinkStoreProvider);
  final saved = await store.readMyLink(uid);
  if (saved != null && parseFollowLink(saved) == uid) return saved;
  final link = buildFollowLink(uid).toString();
  await store.saveMyLink(uid, link);
  return link;
});

/// The result of acting on a follow link.
class FollowLinkResult {
  const FollowLinkResult(this.outcome, {this.targetName});

  final FollowLinkOutcome outcome;

  /// The followed rider's display name, when their profile could be read.
  final String? targetName;
}

/// The one place a follow link turns into a follow — shared by the in-app
/// scanner and links opened from the system camera. The write itself goes
/// through [FollowController] (same notification + count bookkeeping as
/// every Follow button); this only adds the link-specific checks.
final followLinkControllerProvider =
    Provider<FollowLinkController>((ref) => FollowLinkController(ref));

class FollowLinkController {
  FollowLinkController(this._ref);

  final Ref _ref;

  /// Follows the rider [targetUid] (already parsed from a link; null means
  /// the link didn't parse). Signed out, the follow is stashed for after
  /// sign-in and [FollowLinkOutcome.pendingSignIn] is returned.
  Future<FollowLinkResult> followUid(
    String? targetUid, {
    required AppLocalizations l10n,
  }) async {
    final myUid = _ref.read(currentUserProvider)?.uid;
    var following = const <String>{};
    if (myUid != null) {
      try {
        following = await _ref
            .read(followingUidsProvider.future)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Unknown follow set: go ahead — re-following is an idempotent set().
      }
    }

    final pre = precheckFollowLink(
        targetUid: targetUid, myUid: myUid, following: following);
    if (pre == FollowLinkOutcome.pendingSignIn) {
      await _ref.read(followLinkStoreProvider).savePendingFollow(targetUid!);
      return const FollowLinkResult(FollowLinkOutcome.pendingSignIn);
    }

    String? name;
    if (pre == null || pre == FollowLinkOutcome.alreadyFollowing) {
      try {
        final profile = await _ref
            .read(profileRepositoryProvider)
            .getProfile(targetUid!)
            .timeout(const Duration(seconds: 8));
        // A missing doc is a well-formed uid that isn't a rider.
        if (profile == null) {
          return const FollowLinkResult(FollowLinkOutcome.invalid);
        }
        name = profile.bestName;
      } catch (_) {
        // Permission denied (a private/mutual-only profile — rules also deny
        // a doc that doesn't exist, so the two can't be told apart here) or
        // offline: follow anyway, without a name.
      }
    }
    if (pre != null) return FollowLinkResult(pre, targetName: name);

    try {
      await _ref.read(followControllerProvider).setFollowing(
            targetUid!,
            follow: true,
            fallbackName: l10n.aRider,
          );
    } catch (_) {
      return FollowLinkResult(FollowLinkOutcome.failed, targetName: name);
    }
    return FollowLinkResult(FollowLinkOutcome.followed, targetName: name);
  }
}

/// The snackbar text for a [FollowLinkResult].
String followLinkResultMessage(AppLocalizations l10n, FollowLinkResult r) {
  final name = r.targetName ?? l10n.aRider;
  return switch (r.outcome) {
    FollowLinkOutcome.followed => l10n.followLinkFollowed(name),
    FollowLinkOutcome.alreadyFollowing => l10n.followLinkAlreadyFollowing(name),
    FollowLinkOutcome.self => l10n.followLinkSelf,
    FollowLinkOutcome.invalid => l10n.followLinkInvalid,
    FollowLinkOutcome.pendingSignIn => l10n.followLinkSignInFirst,
    FollowLinkOutcome.failed => l10n.followLinkFailed,
  };
}
