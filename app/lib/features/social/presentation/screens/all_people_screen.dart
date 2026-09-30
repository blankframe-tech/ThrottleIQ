import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import 'social_screen.dart';

final allPeopleProvider = FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  
  // Just get recent 100 users for this simple screen
  final repo = ProfileRepository();
  final users = await repo.getRecentUsers(limit: 100);
  return users.where((u) => u.uid != user.uid).toList();
});

class AllPeopleScreen extends ConsumerWidget {
  const AllPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usersAsync = ref.watch(allPeopleProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(l10n.peopleTabLabel, // reuse people tab label or make a new one, peopleTabLabel is good
            style: TextStyle(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold)),
        backgroundColor: context.palette.surface,
        iconTheme: IconThemeData(color: context.palette.textPrimary),
      ),
      body: usersAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(allPeopleProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(l10n.notFollowingAnyoneYet, // not exactly accurate but fine for now, let's just use string literal for now or a l10n
                  style: TextStyle(color: context.palette.textSecondary)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => RiderResultTile(rider: users[i]),
          );
        },
      ),
    );
  }
}
