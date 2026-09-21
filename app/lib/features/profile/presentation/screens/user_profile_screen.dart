import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../core/utils/badges.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/bug_report_sheet.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../social/presentation/providers/follow_providers.dart';
import '../../../social/presentation/providers/notification_providers.dart';
import '../../domain/bike_visibility.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_load_error_view.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

/// A rider's profile: avatar, bio, follow button, total km/rides, earned
/// badges and (permission allowing) their garage. Reached by tapping a
/// rider's name/avatar in "Find riders" search results or on a forum post —
/// and, with [uid] omitted, it's the signed-in rider's OWN profile view,
/// reached from the garage header menu ('/profile').
///
/// Viewing your own profile is deliberately the same screen rather than a
/// parallel "my profile" one — it's the same information, and a second screen
/// would drift. The only differences are the app-bar **Edit** action (which
/// opens [EditProfileScreen] at '/profile/edit') and the garage section
/// sourcing from the local DB instead of the synced cloud mirror.
///
/// Respects [UserProfileEntity.visibility] via firestore.rules (not just a
/// UI check) — a mutual/private profile a viewer isn't permitted to read
/// surfaces as a Firestore permission-denied error on the doc stream, which
/// this screen renders as an explicit "This profile is private" state
/// rather than a raw error. The garage section is gated separately by
/// [canSeeBikes] / [UserProfileEntity.bikesVisibility].
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../stats/presentation/badge_l10n.dart';

class UserProfileScreen extends ConsumerWidget {
  /// The rider to show. Null → the signed-in rider's own profile.
  final String? uid;
  const UserProfileScreen({super.key, this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    final targetUid = uid ?? myUid;
    final isMe = targetUid != null && myUid == targetUid;

    if (targetUid == null) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(title: Text(context.l10n.navProfileLabel)),
        body: Center(
          child: Text(context.l10n.signViewProfile,
              style: TextStyle(color: context.palette.textSecondary)),
        ),
      );
    }

    final profileAsync = ref.watch(profileProvider(targetUid));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(context.l10n.navProfileLabel),
        actions: [
          if (isMe)
            TextButton.icon(
              onPressed: () => context.push('/profile/edit'),
              icon: Icon(Icons.edit_outlined, size: 18, color: context.palette.primary),
              label: Text(context.l10n.edit, style: TextStyle(color: context.palette.primary)),
            )
          else
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.palette.textPrimary),
              onSelected: (value) async {
                if (value == 'block' && myUid != null) {
                  await ref.read(profileRepositoryProvider).blockUser(myUid, targetUid);
                  ref.invalidate(blockedUsersProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.userBlocked)),
                    );
                    context.pop();
                  }
                } else if (value == 'report') {
                  ReportBottomSheet.show(
                    context,
                    reportedId: targetUid,
                    contentType: 'user',
                    contentId: targetUid,
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'report',
                  child: Text(context.l10n.reportUser),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text(context.l10n.blockUser),
                ),
              ],
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ProfileLoadErrorView(
          failure: classifyProfileError(e),
          onRetry: () => ref.invalidate(profileProvider(targetUid)),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(
                  isMe
                      ? context.l10n.tapEditFinishSetting
                      : context.l10n.riderNotFound,
                  style: TextStyle(color: context.palette.textSecondary)),
            );
          }
          return _ProfileBody(profile: profile, isMe: isMe, myUid: myUid);
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final UserProfileEntity profile;
  final bool isMe;
  final String? myUid;
  const _ProfileBody({required this.profile, required this.isMe, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followerCount = ref.watch(followerCountProvider(profile.uid));
    final followingCount = ref.watch(followingCountProvider(profile.uid));
    final isFollowingAsync = isMe ? null : ref.watch(isFollowingProvider(profile.uid));
    final earnedBadges = badgeDefs.where((b) => profile.badgeIds.contains(b.id)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                UserAvatar(photoUrl: profile.photoUrl, name: profile.bestName, radius: 44),
                const SizedBox(height: 12),
                Text(profile.bestName,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: context.palette.textPrimary)),
                if (profile.username != null)
                  Text('@${profile.username}',
                      style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
                // bestName above already prefers the nickname, so only show
                // the real name separately when it isn't what's on top.
                if (profile.displayName.trim().isNotEmpty &&
                    profile.displayName.trim() != profile.bestName)
                  Text(profile.displayName.trim(),
                      style: TextStyle(fontSize: 13, color: context.palette.textTertiary)),
                if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(profile.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
                ],
                if (profile.createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(context.l10n.ridingWithUsSince(DateFormat.yMMMM(kNumericLocale).format(profile.createdAt!)),
                      style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CountStat(label: context.l10n.followersLabel, value: followerCount),
              const SizedBox(width: 28),
              _CountStat(label: context.l10n.followingLabel, value: followingCount),
            ],
          ),
          if (!isMe && myUid != null && isFollowingAsync != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: isFollowingAsync.when(
                    loading: () => const SizedBox(height: 40),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (isFollowing) => ElevatedButton(
                      onPressed: () {
                        final repo = ref.read(followRepositoryProvider);
                        if (isFollowing) {
                          repo.unfollow(myUid!, profile.uid);
                        } else {
                          repo.follow(myUid!, profile.uid);
                          final me = ref.read(myProfileProvider).valueOrNull;
                          ref.read(notificationRepositoryProvider).notifyFollow(
                                toUid: profile.uid,
                                fromUid: myUid!,
                                fromName: me?.bestName ?? context.l10n.aRider,
                                fromPhotoUrl: me?.photoUrl,
                              );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? context.palette.surfaceVariant : context.palette.primary,
                        foregroundColor: isFollowing ? context.palette.textPrimary : Colors.white,
                      ),
                      child: Text(isFollowing ? context.l10n.following : context.l10n.follow),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        final chatId = await ref.read(chatRepositoryProvider).getOrCreateChat(myUid!, profile.uid);
                        if (context.mounted) {
                          context.push('/chats/$chatId', extra: profile);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(mapFirestoreError(e, context.l10n)),
                              action: SnackBarAction(
                                label: context.l10n.report,
                                onPressed: () => BugReportSheet.show(context),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.palette.primary,
                      side: BorderSide(color: context.palette.primary),
                    ),
                    child: Text(context.l10n.message),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: SpeedFormatter.distanceKm(profile.totalDistanceKm * 1000),
                  label: context.l10n.totalDistanceLower,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(value: '${profile.totalRides}', label: context.l10n.ridesLogged),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(context.l10n.badges,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: context.palette.textPrimary)),
          const SizedBox(height: 12),
          earnedBadges.isEmpty
              ? Text(context.l10n.noBadgesEarnedYet,
                  style: TextStyle(fontSize: 13, color: context.palette.textTertiary))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in earnedBadges)
                      Chip(
                        avatar: Icon(Icons.military_tech, size: 16, color: context.palette.primary),
                        label: Text(b.localizedName(context.l10n)),
                        backgroundColor: context.palette.surface,
                        side: BorderSide(color: context.palette.border),
                      ),
                  ],
                ),
          // The garage. Hidden outright — no placeholder, nothing to probe —
          // when this viewer isn't allowed to see it. The same decision is
          // re-made server-side in firestore.rules; this is the cosmetic half.
          if (canSeeBikes(
            viewerUid: myUid ?? '',
            ownerUid: profile.uid,
            visibility: profile.bikesVisibility,
            viewerFollowsOwner: isFollowingAsync?.valueOrNull ?? false,
          )) ...[
            const SizedBox(height: 24),
            _GarageSection(profile: profile, isMe: isMe),
          ],
        ],
      ),
    );
  }
}

/// The bikes list on a profile. For the signed-in rider this reads the local
/// garage (authoritative, works offline, includes bikes not yet synced); for
/// anyone else it reads the synced `users/{uid}/bikes` mirror, and renders
/// nothing at all if that read is refused or empty.
class _GarageSection extends ConsumerWidget {
  final UserProfileEntity profile;
  final bool isMe;
  const _GarageSection({required this.profile, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bikesAsync = isMe
        ? ref.watch(garageProvider)
        : ref.watch(riderBikesProvider(profile.uid));

    final bikes = bikesAsync.valueOrNull ?? const <BikeEntity>[];
    // Someone else's empty/denied garage shows no section at all rather than
    // an empty-state that would leak "this rider has no bikes".
    if (!isMe && bikes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(isMe ? context.l10n.myGarageLower : context.l10n.garage,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary)),
            ),
            if (isMe)
              Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: context.palette.textTertiary),
                  const SizedBox(width: 4),
                  Text(bikesVisibilityLabel(profile.bikesVisibility, context.l10n),
                      style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                ],
              ),
          ],
        ),
        if (isMe) ...[
          const SizedBox(height: 2),
          Text(context.l10n.whoCanSeeBikesChangeUnderEdit,
              style: TextStyle(fontSize: 11, color: context.palette.textTertiary)),
        ],
        const SizedBox(height: 12),
        if (bikes.isEmpty)
          Text(context.l10n.noBikesYet,
              style: TextStyle(fontSize: 13, color: context.palette.textTertiary))
        else
          for (final bike in bikes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(context.shape.radiusMd),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.two_wheeler, size: 20, color: context.palette.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bike.displayName,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textPrimary)),
                          Text(
                            [
                              if (bike.cc != null) '${bike.cc}cc',
                              SpeedFormatter.distanceKm(bike.totalDistanceM),
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _CountStat extends ConsumerWidget {
  final String label;
  final AsyncValue<int> value;
  const _CountStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Text(value.valueOrNull?.toString() ?? '—',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: context.palette.textPrimary)),
        Text(label, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: context.palette.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
        ],
      ),
    );
  }
}
