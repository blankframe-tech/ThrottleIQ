import '../../../profile/domain/entities/user_profile_entity.dart';

/// How many "Suggested for you" riders the People tab shows (issues §90.A5).
const int kSuggestionCap = 10;

/// How many of the rider's followers the suggestion builder samples when
/// looking for people to follow back. Bounded so a rider with thousands of
/// followers doesn't read thousands of edges every time the tab opens.
const int kSuggestionFollowerSample = 30;

/// How many recently-joined riders are fetched to top the list up.
const int kSuggestionRecentUsersLimit = 20;

/// Followers the rider doesn't follow back yet — the strongest suggestions —
/// minus themselves and anyone either side has blocked, capped at [cap] so
/// the caller fetches at most [cap] profiles.
List<String> followBackCandidates({
  required String myUid,
  required Iterable<String> followers,
  required Set<String> following,
  required Set<String> blocked,
  int cap = kSuggestionCap,
}) {
  final out = <String>[];
  final seen = <String>{};
  for (final uid in followers) {
    if (out.length >= cap) break;
    if (uid == myUid || following.contains(uid) || blocked.contains(uid)) {
      continue;
    }
    if (seen.add(uid)) out.add(uid);
  }
  return out;
}

/// Follow-back profiles first, then recent riders, de-duplicated, never the
/// rider themselves, someone they already follow, or a blocked rider — and
/// at most [cap] in all.
List<UserProfileEntity> mergeSuggestions({
  required String myUid,
  required List<UserProfileEntity> followBack,
  required List<UserProfileEntity> recent,
  required Set<String> following,
  required Set<String> blocked,
  int cap = kSuggestionCap,
}) {
  final out = <UserProfileEntity>[];
  final seen = <String>{};
  for (final p in [...followBack, ...recent]) {
    if (out.length >= cap) break;
    if (p.uid == myUid ||
        following.contains(p.uid) ||
        blocked.contains(p.uid)) {
      continue;
    }
    if (seen.add(p.uid)) out.add(p);
  }
  return out;
}
