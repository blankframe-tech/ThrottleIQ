import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_providers.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUidsAsync = ref.watch(blockedUsersProvider);
    final myUid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(context.l10n.blockedUsers)),
      body: blockedUidsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(blockedUsersProvider),
        ),
        data: (blockedUids) {
          if (blockedUids.isEmpty) {
            return Center(
              child: Text(
                context.l10n.noBlockedUsers,
                style: TextStyle(color: context.palette.textSecondary),
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedUids.length,
            itemBuilder: (context, index) {
              final uid = blockedUids.elementAt(index);
              final profileAsync = ref.watch(profileProvider(uid));

              return profileAsync.when(
                loading: () => ListTile(title: Text(context.l10n.loading)),
                error: (e, _) => ListTile(title: Text(context.l10n.errorLoadingUser)),
                data: (profile) {
                  if (profile == null) {
                    return ListTile(title: Text(context.l10n.unknownUser));
                  }

                  return ListTile(
                    leading: UserAvatar(photoUrl: profile.photoUrl, name: profile.bestName, radius: 20),
                    title: Text(profile.bestName, style: TextStyle(color: context.palette.textPrimary)),
                    subtitle: profile.username != null ? Text('@${profile.username}', style: TextStyle(color: context.palette.textSecondary)) : null,
                    trailing: TextButton(
                      onPressed: () async {
                        if (myUid == null) return;
                        await ref.read(profileRepositoryProvider).unblockUser(myUid, uid);
                        ref.invalidate(blockedUsersProvider);
                        ref.invalidate(profileProvider(uid));
                      },
                      child: Text(context.l10n.unblock, style: TextStyle(color: context.palette.primary)),
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
