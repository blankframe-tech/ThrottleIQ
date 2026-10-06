import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'social_screen.dart';

/// Riders fetched per "Load more" step on [AllPeopleScreen].
const int kAllPeoplePageSize = 30;

/// Upper bound on how far "Load more" grows the list.
const int kAllPeopleMaxRiders = 150;

/// How many recent riders [allPeopleProvider] currently asks for. Starts at
/// one page (it used to read 100 profiles on every open) and grows by
/// [kAllPeoplePageSize] per "Load more".
///
/// `ProfileRepository.getRecentUsers` takes no cursor yet, so each step
/// re-reads the earlier pages too; a `startAfter` parameter there would make
/// this a true cursor (issues §90.A — LOW).
final allPeopleLimitProvider =
    StateProvider.autoDispose<int>((ref) => kAllPeoplePageSize);

final allPeopleProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final limit = ref.watch(allPeopleLimitProvider);
  final blocked = ref.watch(blockedUsersProvider).valueOrNull ?? const {};
  final users =
      await ref.watch(profileRepositoryProvider).getRecentUsers(limit: limit);
  return users
      .where((u) => u.uid != user.uid && !blocked.contains(u.uid))
      .toList();
});

class AllPeopleScreen extends ConsumerWidget {
  const AllPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usersAsync = ref.watch(allPeopleProvider);
    final limit = ref.watch(allPeopleLimitProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(l10n.peopleTabLabel,
            style: TextStyle(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold)),
        backgroundColor: context.palette.surface,
        iconTheme: IconThemeData(color: context.palette.textPrimary),
      ),
      body: usersAsync.when(
        // Keep showing the rows already loaded while a "Load more" is in
        // flight instead of blanking the list.
        skipLoadingOnReload: true,
        loading: () => Center(
            child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(allPeopleProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noOtherRidersYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.palette.textSecondary)),
              ),
            );
          }
          // A full page back means there may be more; a short one means the
          // query ran out of riders. (Self/blocked filtering can shave a
          // couple off, hence the slack.)
          final mayHaveMore =
              users.length >= limit - 2 && limit < kAllPeopleMaxRiders;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length + (mayHaveMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == users.length) {
                return Center(
                  child: usersAsync.isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                              color: context.palette.primary),
                        )
                      : OutlinedButton(
                          onPressed: () => ref
                              .read(allPeopleLimitProvider.notifier)
                              .state = limit + kAllPeoplePageSize,
                          child: Text(l10n.loadMore),
                        ),
                );
              }
              // RiderResultTile's FollowButton already shows "Following" for
              // riders the viewer follows, straight off the live follow set.
              return RiderResultTile(rider: users[i]);
            },
          );
        },
      ),
    );
  }
}
