import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_providers.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUidsAsync = ref.watch(blockedUsersProvider);
    final myUid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Blocked Users')),
      body: blockedUidsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (blockedUids) {
          if (blockedUids.isEmpty) {
            return Center(
              child: Text(
                'No blocked users',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedUids.length,
            itemBuilder: (context, index) {
              final uid = blockedUids.elementAt(index);
              final profileAsync = ref.watch(profileProvider(uid));

              return profileAsync.when(
                loading: () => const ListTile(title: Text('Loading...')),
                error: (e, _) => const ListTile(title: Text('Error loading user')),
                data: (profile) {
                  if (profile == null) {
                    return const ListTile(title: Text('Unknown user'));
                  }

                  return ListTile(
                    leading: UserAvatar(photoUrl: profile.photoUrl, name: profile.bestName, radius: 20),
                    title: Text(profile.bestName, style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: profile.username != null ? Text('@${profile.username}', style: TextStyle(color: AppColors.textSecondary)) : null,
                    trailing: TextButton(
                      onPressed: () async {
                        if (myUid == null) return;
                        await ref.read(profileRepositoryProvider).unblockUser(myUid, uid);
                        ref.invalidate(blockedUsersProvider);
                        ref.invalidate(profileProvider(uid));
                      },
                      child: Text('Unblock', style: TextStyle(color: AppColors.primary)),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
