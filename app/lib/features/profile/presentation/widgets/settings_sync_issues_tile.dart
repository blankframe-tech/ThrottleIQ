import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../screens/sync_issues_screen.dart';
import 'settings_link_tile.dart';

/// Settings → Sync issues (§69.O4). Only shown while the outbox has given up
/// on something, so the rider isn't handed a permanent "0 issues" row.
class SettingsSyncIssuesTile extends ConsumerWidget {
  const SettingsSyncIssuesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(syncIssuesProvider).valueOrNull?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SettingsLinkTile(
        icon: Icons.sync_problem,
        accent: context.palette.warning,
        title: context.l10n.syncIssues,
        subtitle: count == 1
            ? context.l10n.n1UpdateCouldntBe
            : context.l10n.updatesCouldntBeSent(count),
        onTap: () => context.push('/sync-issues'),
      ),
    );
  }
}
