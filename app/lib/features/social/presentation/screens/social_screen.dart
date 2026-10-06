import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/riding_score.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/ride_route_map.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../forums/data/repositories/forum_repository.dart';
import '../../../forums/domain/entities/forum_entity.dart';
import '../../../forums/presentation/screens/forums_home_screen.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/group_ride_entity.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/feed_sort.dart';
import '../providers/follow_providers.dart';
import '../providers/group_ride_providers.dart';
import '../providers/notification_providers.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../providers/ride_feed_provider.dart';
import '../widgets/follow_button.dart';
import '../widgets/ride_media_collage.dart';
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/i18n/l10n_context.dart';

part 'social_search.dart';
part 'social_feed_tab.dart';
part 'social_people_tab.dart';

/// How long the header search waits after the last keystroke before querying.
/// Rider search runs a Firestore prefix query per keystroke otherwise.
const _searchDebounce = Duration(milliseconds: 400);

/// How long the forum list behind the AppBar search is reused.
const _forumIndexTtl = Duration(minutes: 10);

/// Riders matching a search query — shared by the AppBar's combined search
/// (riders + forums) and the People tab's rider-only search.
final _riderSearchProvider = FutureProvider.autoDispose
    .family<List<UserProfileEntity>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final repo = ref.watch(profileRepositoryProvider);
  // An email needs the exact-match query; anything else (with or without a
  // leading @) is a username prefix. Same rule the old Find-riders sheet used.
  final looksLikeEmail =
      q.contains('@') && q.contains('.') && !q.startsWith('@');
  return looksLikeEmail ? repo.searchByEmail(q) : repo.searchByUsername(q);
});

/// The forum list the AppBar search filters, fetched once and kept for
/// [_forumIndexTtl] (issues §90.A7). `searchForums` used to re-read its 200
/// forums on every keystroke — "royal enfield" alone cost ~2,800 reads.
final _forumSearchIndexProvider =
    FutureProvider.autoDispose<List<ForumEntity>>((ref) async {
  final forums = await ForumRepository().getForumsForSearch();
  final link = ref.keepAlive();
  final ttl = Timer(_forumIndexTtl, link.close);
  ref.onDispose(ttl.cancel);
  return forums;
});

/// Forums matching the AppBar's combined search box — an in-memory filter
/// over [_forumSearchIndexProvider], so typing costs no reads.
final _forumSearchProvider = FutureProvider.autoDispose
    .family<List<ForumEntity>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return filterForumsByName(await ref.watch(_forumSearchIndexProvider.future), q);
});

/// Profiles of everyone the signed-in rider follows — the People tab's
/// "Following" list. Keyed off the live [followingUidsProvider] (issues
/// §90.A3): the one-shot follow list it used before was never invalidated,
/// so a follow/unfollow never showed here until restart.
///
/// One unreadable profile (private / mutual-only visibility) is dropped
/// rather than failing the whole list.
final _followingProfilesProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final ids = await ref.watch(followingUidsProvider.future);
  if (ids.isEmpty) return const [];
  final repo = ref.watch(profileRepositoryProvider);
  final profiles = await Future.wait(ids.map((id) async {
    try {
      return await repo.getProfile(id);
    } catch (_) {
      return null;
    }
  }));
  return profiles.whereType<UserProfileEntity>().toList();
});

/// Social hub: Rides (the ride feed), People (rider search + who you
/// follow), and Forums. Places moved to its own bottom-nav tab in Epic E.
///
/// The AppBar's search icon opens a combined rider+forum search
/// ([_SocialSearchDelegate]) reachable from any tab, while the People tab
/// carries its own rider-only search box for the common case of "find a
/// specific rider" without leaving the tab.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          titleSpacing: AppDimensions.paddingMd,
          title: Text('Social',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: context.palette.textPrimary)),
          actions: [
            IconButton(
              tooltip: context.l10n.searchRidersForums,
              icon: Icon(Icons.search,
                  color: context.palette.textSecondary, size: 24),
              onPressed: () =>
                  showSearch(context: context, delegate: _SocialSearchDelegate()),
            ),
            Consumer(
              builder: (_, ref, __) => NotificationBellButton(
                  unreadCount: ref.watch(unreadNotificationCountProvider)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: context.palette.textPrimary,
            unselectedLabelColor: context.palette.textSecondary,
            indicatorColor: context.palette.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            dividerColor: context.palette.border,
            tabs: [
              Tab(text: context.l10n.navRidesLabel),
              Tab(text: context.l10n.peopleTabLabel),
              Tab(text: context.l10n.forums),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _FeedTab(),
            const _PeopleTab(),
            // The Hubs lens's search shortcut opens this same AppBar search
            // rather than carrying a second, forum-only search box.
            ForumsHomeScreen(
              onOpenSearch: () =>
                  showSearch(context: context, delegate: _SocialSearchDelegate()),
            ),
          ],
        ),
      ),
    );
  }
}
