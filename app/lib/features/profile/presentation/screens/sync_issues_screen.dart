import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/daos/outbox_dao.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/error_view.dart';

/// The signed-in rider's outbox entries that the queue gave up on — §69.O4.
///
/// Scoped to the current account: on a shared phone another rider's parked
/// writes are theirs to retry or discard, not this one's (and `drain()` would
/// skip them under this login anyway). Refreshes whenever the outbox reports
/// a change, so a retry that lands drops off the list on its own.
final syncIssuesProvider =
    FutureProvider.autoDispose<List<OutboxEntry>>((ref) async {
  final outbox = ref.watch(outboxServiceProvider);
  final uid = ref.watch(currentUserProvider)?.uid;
  final sub = outbox.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  final dead = await outbox.deadEntries();
  return [
    for (final e in dead)
      if (outboxEntryOwner(e) == null || outboxEntryOwner(e) == uid) e,
  ];
});

/// What a queued write was, in the rider's words.
String syncIssueLabel(String kind) => switch (kind) {
      OutboxKind.shareRide => 'Ride share',
      OutboxKind.liveSessionTeardown => 'Ending a live share',
      OutboxKind.maintenanceLog => 'Maintenance log',
      _ => 'Cloud update',
    };

/// Settings → Sync issues: writes that couldn't be delivered after repeated
/// tries, each with Retry and Discard. Reached from the settings tile, which
/// only appears while there is something here.
class SyncIssuesScreen extends ConsumerWidget {
  const SyncIssuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(syncIssuesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sync issues')),
      body: issuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(syncIssuesProvider),
        ),
        data: (issues) {
          if (issues.isEmpty) {
            return Center(
              child: Text(
                'Everything is synced',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: issues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SyncIssueCard(entry: issues[i]),
          );
        },
      ),
    );
  }
}

class _SyncIssueCard extends ConsumerStatefulWidget {
  const _SyncIssueCard({required this.entry});

  final OutboxEntry entry;

  @override
  ConsumerState<_SyncIssueCard> createState() => _SyncIssueCardState();
}

class _SyncIssueCardState extends ConsumerState<_SyncIssueCard> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    final outbox = ref.read(outboxServiceProvider);
    final delivered = await outbox.retryDead(widget.entry.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(delivered
          ? 'Synced'
          : "Couldn't sync yet. We'll keep trying in the background."),
    ));
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Discard this update?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text("It won't be sent. This can't be undone.",
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Discard', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(outboxServiceProvider).discard(widget.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final queued = entry.createdAt.toLocal();
    final queuedLabel = '${queued.year}-'
        '${queued.month.toString().padLeft(2, '0')}-'
        '${queued.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_problem, color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(syncIssueLabel(entry.kind),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Text(queuedLabel,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          if (entry.lastError != null) ...[
            const SizedBox(height: 6),
            Text(entry.lastError!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : _discard,
                child: Text('Discard', style: TextStyle(color: AppColors.danger)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : _retry,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Retry', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
