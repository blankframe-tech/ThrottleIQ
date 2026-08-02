import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../core/utils/badges.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../social/presentation/providers/follow_providers.dart';
import '../../../social/presentation/providers/notification_providers.dart';
import '../../domain/bike_visibility.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../providers/profile_providers.dart';

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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Text('Sign in to view your profile',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final profileAsync = ref.watch(profileProvider(targetUid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (isMe)
            TextButton.icon(
              onPressed: () => context.push('/profile/edit'),
              icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              label: Text('Edit', style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: AppColors.textTertiary),
                SizedBox(height: 12),
                Text('This profile is private',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(
                  isMe
                      ? 'Tap Edit to finish setting up your profile'
                      : 'Rider not found',
                  style: TextStyle(color: AppColors.textSecondary)),
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
                        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (profile.username != null)
                  Text('@${profile.username}',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                // bestName above already prefers the nickname, so only show
                // the real name separately when it isn't what's on top.
                if (profile.displayName.trim().isNotEmpty &&
                    profile.displayName.trim() != profile.bestName)
                  Text(profile.displayName.trim(),
                      style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(profile.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
                if (profile.createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text('Riding with us since ${DateFormat.yMMMM(kNumericLocale).format(profile.createdAt!)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CountStat(label: 'followers', value: followerCount),
              const SizedBox(width: 28),
              _CountStat(label: 'following', value: followingCount),
            ],
          ),
          if (!isMe && myUid != null && isFollowingAsync != null) ...[
            const SizedBox(height: 16),
            isFollowingAsync.when(
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
                          fromName: me?.bestName ?? 'A rider',
                          fromPhotoUrl: me?.photoUrl,
                        );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? AppColors.surfaceVariant : AppColors.primary,
                  foregroundColor: isFollowing ? AppColors.textPrimary : Colors.white,
                ),
                child: Text(isFollowing ? 'Following' : 'Follow'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: SpeedFormatter.distanceKm(profile.totalDistanceKm * 1000),
                  label: 'total distance',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(value: '${profile.totalRides}', label: 'rides logged'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Badges',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          earnedBadges.isEmpty
              ? Text('No badges earned yet',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in earnedBadges)
                      Chip(
                        avatar: Icon(Icons.military_tech, size: 16, color: AppColors.primary),
                        label: Text(b.name),
                        backgroundColor: AppColors.surface,
                        side: BorderSide(color: AppColors.border),
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
              child: Text(isMe ? 'My garage' : 'Garage',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            if (isMe)
              Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(bikesVisibilityLabel(profile.bikesVisibility),
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
          ],
        ),
        if (isMe) ...[
          const SizedBox(height: 2),
          Text('Who can see my bikes — change this under Edit',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
        const SizedBox(height: 12),
        if (bikes.isEmpty)
          Text('No bikes yet',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary))
        else
          for (final bike in bikes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.two_wheeler, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bike.displayName,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Text(
                            [
                              if (bike.cc != null) '${bike.cc}cc',
                              SpeedFormatter.distanceKm(bike.totalDistanceM),
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
