import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../providers/garage_provider.dart';
import '../widgets/bike_photo.dart';
import '../../domain/entities/bike_entity.dart';
import '../../../forums/data/repositories/forum_repository.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';

class BikeDetailScreen extends ConsumerWidget {
  final String bikeId;
  const BikeDetailScreen({super.key, required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // allBikesProvider, not garageProvider: an archived bike is still
    // openable (from the garage's "Archived bikes" section) to unarchive it.
    // Falls back to the garage while that list is still loading.
    final bikes = ref.watch(allBikesProvider).valueOrNull ??
        ref.watch(garageProvider).valueOrNull ??
        [];
    final bike = bikes.where((b) => b.id == bikeId).firstOrNull;
    final ridesAsync = ref.watch(rideHistoryProvider(bikeId));

    if (bike == null) {
      return Scaffold(
        body: Center(child: Text('Bike not found', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(bike.isArchived
            ? '${bike.displayName} (archived)'
            : bike.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Discuss this bike',
            onPressed: () => _openForum(context, bike),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/home/profile/$bikeId/edit'),
          ),
          if (bike.isArchived)
            IconButton(
              icon: const Icon(Icons.unarchive_outlined),
              tooltip: 'Unarchive bike',
              onPressed: () => _unarchive(context, ref),
            )
          else
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Archive or delete bike',
              onPressed: () => _confirmRemove(context, ref, bike),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image / header. Went through [BikePhoto] rather than a
            // DecorationImage: a saved imagePath can point at a file that no
            // longer exists (or at nothing at all, for a bike synced down from
            // another device), and only Image.file's errorBuilder can fall
            // back to the icon when the decode fails.
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: BikePhoto(
                imagePath: bike.imagePath,
                width: double.infinity,
                height: 180,
                iconSize: 72,
                backgroundColor: Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
            ),
            const SizedBox(height: 16),

            // Stats grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                StatCard(
                  label: 'Total Distance',
                  value: bike.totalDistanceKm.toStringAsFixed(1),
                  unit: 'km',
                  icon: Icons.route,
                  isPrimary: true,
                ),
                StatCard(
                  label: 'Total Rides',
                  value: '${bike.rideCount}',
                  icon: Icons.flag_outlined,
                  valueColor: AppColors.primaryHighlight,
                  isPrimary: true,
                ),
                if (bike.odometerKm != null)
                  StatCard(
                    label: 'Odometer',
                    value: bike.currentOdometerKm.toStringAsFixed(0),
                    unit: 'km',
                    icon: Icons.speed_outlined,
                  ),
                if (bike.cc != null)
                  StatCard(label: 'Engine', value: '${bike.cc}', unit: 'cc', icon: Icons.settings),
                if (bike.year != null)
                  StatCard(label: 'Year', value: '${bike.year}', icon: Icons.calendar_today_outlined),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openForum(context, bike),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Discuss this bike'),
              ),
            ),
            const SizedBox(height: 16),
            _ServiceCard(bikeId: bikeId),
            const SizedBox(height: 24),

            // Ride history
            Text('Ride History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ridesAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Text('$e', style: TextStyle(color: AppColors.danger)),
              data: (rides) {
                if (rides.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No rides yet for this bike',
                          style: TextStyle(color: AppColors.textTertiary)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final ride = rides[i];
                    return Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: InkWell(
                        onTap: () => context.push('/ride/summary/${ride.id}'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(ride.startTime),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${SpeedFormatter.distanceKm(ride.distanceM)} · ${SpeedFormatter.durationFromSeconds(ride.durationSeconds ?? 0)}',
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryHighlight,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForum(BuildContext context, BikeEntity bike) async {
    try {
      final forum = await ForumRepository().getOrCreateForum(brand: bike.brand, model: bike.model);
      if (!context.mounted) return;
      context.push('/forums/${forum.id}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open forum: $e')),
      );
    }
  }

  // Pops with a result rather than popping-then-navigating inline: a
  // Navigator.pop immediately followed by a context.go/push in the same
  // synchronous callback races the dialog's imperative route removal
  // against go_router's declarative page-list update on the same
  // Navigator, which can produce two pages computing the same key —
  // Flutter's Navigator._updatePages assertion
  // "'!keyReservation.contains(key)': is not true." Awaiting the dialog's
  // own Future and navigating only after it fully resolves (mirroring
  // active_ride_screen.dart's stop-ride confirm, already safe) guarantees
  // the dialog's route is completely gone before anything else touches
  // the Navigator.
  //
  // Archive is the primary choice (claude_sol §2.1.1): the only option this
  // dialog used to offer was a delete that took every ride on the bike with
  // it, which is rarely what "I sold this bike" means.
  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, BikeEntity bike) async {
    final choice = await showDialog<_RemoveChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove ${bike.displayName}?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
            'Archiving hides this bike from your garage and bike pickers. '
            'Its rides stay in your history and stats, and you can unarchive '
            'it any time.',
            style: TextStyle(color: AppColors.textSecondary)),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            key: const Key('bike-delete-with-rides'),
            onPressed: () =>
                Navigator.pop(dialogContext, _RemoveChoice.deleteWithRides),
            child: Text('Delete bike and all its rides',
                style: TextStyle(color: AppColors.danger)),
          ),
          FilledButton(
            key: const Key('bike-archive'),
            onPressed: () =>
                Navigator.pop(dialogContext, _RemoveChoice.archive),
            child: const Text('Archive bike (keep rides)'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == _RemoveChoice.archive) {
      try {
        await ref.read(garageProvider.notifier).archiveBike(bikeId);
        if (context.mounted) context.go('/home/profile');
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not archive this bike: $e')),
        );
      }
      return;
    }

    final typed = await showDialog<bool>(
      context: context,
      builder: (_) => TypeToDeleteBikeDialog(bike: bike),
    );
    if (typed != true || !context.mounted) return;

    // Awaited, and errors surfaced. Previously this was fire-and-forget and
    // navigated away regardless, so when the delete failed (it deadlocked —
    // see BikeDao.delete) the rider was returned to a garage that still had
    // the bike in it, with nothing explaining why.
    try {
      await ref.read(garageProvider.notifier).deleteBike(bikeId);
      if (context.mounted) context.go('/home/profile');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete this bike: $e')),
      );
    }
  }

  Future<void> _unarchive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(garageProvider.notifier).unarchiveBike(bikeId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bike is back in your garage')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unarchive this bike: $e')),
      );
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

enum _RemoveChoice { archive, deleteWithRides }

/// Second step of the destructive path: the rider types the bike's name
/// before "Delete" enables. Deleting takes every ride on the bike with it,
/// here and in the cloud, and there is no undo.
class TypeToDeleteBikeDialog extends StatefulWidget {
  final BikeEntity bike;
  const TypeToDeleteBikeDialog({super.key, required this.bike});

  /// What the rider has to type: brand and model, without the year, so the
  /// check is about intent rather than punctuation.
  static String confirmationText(BikeEntity bike) =>
      '${bike.brand} ${bike.model}'.trim();

  @override
  State<TypeToDeleteBikeDialog> createState() => _TypeToDeleteBikeDialogState();
}

class _TypeToDeleteBikeDialogState extends State<TypeToDeleteBikeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text.trim().toLowerCase() ==
      TypeToDeleteBikeDialog.confirmationText(widget.bike).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final expected = TypeToDeleteBikeDialog.confirmationText(widget.bike);
    final rides = widget.bike.rideCount;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Delete bike and all its rides?',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'This permanently deletes $rides ride${rides == 1 ? '' : 's'}, '
              "their routes and this bike's maintenance log, on this phone "
              'and in the cloud. Type "$expected" to confirm.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('bike-delete-confirm-field'),
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: expected),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(
          key: const Key('bike-delete-confirm'),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: Text('Delete',
              style: TextStyle(
                  color: _matches ? AppColors.danger : AppColors.textTertiary)),
        ),
      ],
    );
  }
}

/// "Service & maintenance" summary for one bike: the most urgent check and a
/// way into the full list. Bike detail had no maintenance entry point at all
/// (claude_sol.md §3.2.3), so the only route in was the Maintenance tab with
/// whichever bike happened to be active.
class _ServiceCard extends ConsumerWidget {
  final String bikeId;
  const _ServiceCard({required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sorted most-urgent first by the provider.
    final reminders = ref.watch(maintenanceRemindersProvider(bikeId));
    final next = reminders.firstOrNull;

    final (String summary, Color tone) = switch (next) {
      null => ('Using default service intervals', AppColors.textSecondary),
      MaintenanceReminder(status: ReminderStatus.overdue) => (
          '${next.serviceType.label} · overdue by '
              '${(next.kmSinceService - next.kmLimit).toStringAsFixed(0)} km',
          AppColors.danger,
        ),
      _ => (
          '${next.serviceType.label} · due in '
              '${(next.kmLimit - next.kmSinceService).clamp(0, double.infinity).toStringAsFixed(0)} km',
          next.status == ReminderStatus.dueSoon
              ? AppColors.warning
              : AppColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Service & maintenance',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Next: $summary', style: TextStyle(fontSize: 14, color: tone)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () =>
                    context.push('/home/maintenance/configure?bikeId=$bikeId'),
                child: const Text('Intervals'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () =>
                    context.push('/home/maintenance?bikeId=$bikeId'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View all'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
