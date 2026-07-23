import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/badges.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/presentation/providers/follow_providers.dart';
import '../../../social/presentation/providers/notification_providers.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../providers/profile_providers.dart';

/// A rider's public profile: avatar, bio, follow button, total km/rides and
/// earned badges. Reached by tapping a rider's name/avatar in "Find riders"
/// search results or on a forum post — there was previously no way to view
/// anyone's profile but your own.
///
/// Respects [UserProfileEntity.visibility] via firestore.rules (not just a
/// UI check) — a mutual/private profile a viewer isn't permitted to read
/// surfaces as a Firestore permission-denied error on the doc stream, which
/// this screen renders as an explicit "This profile is private" state
/// rather than a raw error.
class UserProfileScreen extends ConsumerWidget {
  final String uid;
  const UserProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(uid));
    final myUid = ref.watch(currentUserProvider)?.uid;
    final isMe = myUid == uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
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
            return const Center(
              child: Text('Rider not found', style: TextStyle(color: AppColors.textSecondary)),
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
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (profile.username != null)
                  Text('@${profile.username}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(profile.bio!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
          const Text('Badges',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          earnedBadges.isEmpty
              ? const Text('No badges earned yet',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in earnedBadges)
                      Chip(
                        avatar: const Icon(Icons.military_tech, size: 16, color: AppColors.primary),
                        label: Text(b.name),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                  ],
                ),
        ],
      ),
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
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
