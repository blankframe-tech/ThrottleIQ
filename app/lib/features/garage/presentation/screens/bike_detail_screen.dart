import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../providers/garage_provider.dart';
import '../../data/bike_archive_service.dart';
import '../widgets/bike_photo.dart';
import '../../domain/entities/bike_entity.dart';
import '../../../forums/data/repositories/forum_repository.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../maintenance/presentation/providers/fuel_provider.dart';
import '../../../maintenance/presentation/widgets/forecast_text.dart'
    show shortDate;
import '../../../maintenance/presentation/widgets/next_due_line.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

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
        body: Center(
            child: Text(context.l10n.bikeNotFound,
                style: TextStyle(color: context.palette.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(bike.isArchived
            ? context.l10n.archived(bike.displayName)
            : bike.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: context.l10n.discussThisBike,
            onPressed: () => _openForum(context, bike),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/home/profile/$bikeId/edit'),
          ),
          if (bike.isArchived) ...[
            IconButton(
              icon: const Icon(Icons.unarchive_outlined),
              tooltip: context.l10n.unarchiveBike,
              onPressed: () => _unarchive(context, ref),
            ),
            IconButton(
              key: const Key('bike-delete-now'),
              icon: Icon(Icons.delete_forever_outlined,
                  color: context.palette.danger),
              tooltip: context.l10n.deleteNowAction,
              onPressed: () => _deleteNow(context, ref, bike),
            ),
          ] else
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.palette.danger),
              tooltip: context.l10n.archiveDeleteBike,
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
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(context.shape.radiusLg),
                border: Border.all(color: context.palette.border),
              ),
              child: BikePhoto(
                imagePath: bike.imagePath,
                width: double.infinity,
                height: 180,
                iconSize: 72,
                backgroundColor: Colors.transparent,
                borderRadius: BorderRadius.circular(context.shape.radiusLg),
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
                  label: context.l10n.totalDistance,
                  value: bike.totalDistanceKm.toStringAsFixed(1),
                  unit: 'km',
                  icon: Icons.route,
                  isPrimary: true,
                ),
                StatCard(
                  label: context.l10n.totalRides,
                  value: '${bike.rideCount}',
                  icon: Icons.flag_outlined,
                  valueColor: context.palette.primaryHighlight,
                  isPrimary: true,
                ),
                if (bike.odometerKm != null)
                  StatCard(
                    label: context.l10n.odometer,
                    value: bike.currentOdometerKm.toStringAsFixed(0),
                    unit: 'km',
                    icon: Icons.speed_outlined,
                  ),
                if (bike.cc != null)
                  StatCard(
                      label: context.l10n.engine,
                      value: '${bike.cc}',
                      unit: 'cc',
                      icon: Icons.settings),
                if (bike.year != null)
                  StatCard(
                      label: context.l10n.year,
                      value: '${bike.year}',
                      icon: Icons.calendar_today_outlined),
              ],
            ),
            const SizedBox(height: 16),
            // "Discuss in Forum": the model's board, or straight into a new
            // question for its owners.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openForum(context, bike),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.palette.primary,
                      side: BorderSide(color: context.palette.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.forum_outlined),
                    label: Text(context.l10n.discussThisBike,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('bike_ask_owners'),
                    onPressed: () => _openForum(context, bike, compose: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.palette.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.help_outline),
                    label: Text(context.l10n.askOwners,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ServiceCard(bikeId: bikeId),
            const SizedBox(height: 12),
            _FuelCard(bikeId: bikeId),
            const SizedBox(height: 24),

            // Ride history
            Text(context.l10n.rideHistory,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary)),
            const SizedBox(height: 12),
            ridesAsync.when(
              loading: () => Center(
                  child: CircularProgressIndicator(
                      color: context.palette.primary)),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(rideHistoryProvider(bikeId)),
              ),
              data: (rides) {
                if (rides.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(context.l10n.noRidesYetThis,
                          style:
                              TextStyle(color: context.palette.textTertiary)),
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
                        color: context.palette.surface,
                        borderRadius:
                            BorderRadius.circular(context.shape.radiusMd),
                        border: Border.all(color: context.palette.border),
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
                                        color: context.palette.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${SpeedFormatter.distanceKm(ride.distanceM)} · ${SpeedFormatter.durationFromSeconds(ride.durationSeconds ?? 0)}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: context.palette.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: context.palette.primaryHighlight,
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

  Future<void> _openForum(BuildContext context, BikeEntity bike,
      {bool compose = false}) async {
    try {
      final forum = await ForumRepository()
          .getOrCreateForum(brand: bike.brand, model: bike.model);
      if (!context.mounted) return;
      context.push('/forums/${forum.id}${compose ? '?compose=1' : ''}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenForum(e))),
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
  // Archive is the primary choice (grill §2.1.1): the only option this
  // dialog used to offer was a delete that took every ride on the bike with
  // it, which is rarely what "I sold this bike" means.
  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, BikeEntity bike) async {
    final cleanup = await showDialog<ArchiveCleanup>(
      context: context,
      builder: (_) => ArchiveBikeDialog(bike: bike),
    );
    if (cleanup == null || !context.mounted) return;

    try {
      await ref
          .read(garageProvider.notifier)
          .archiveBike(bike, cleanup: cleanup);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(cleanup.sharedRides
                ? context.l10n.couldNotArchiveSharedRides
                : context.l10n.couldNotArchiveThis(e))),
      );
      return;
    }
    if (!context.mounted) return;

    final deleteNow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ArchivedNoticeDialog(
        bike: bike,
        purgeDate: _formatDate(DateTime.now().add(kArchiveRetention)),
        onExport: () => _export(dialogContext, ref, bike),
      ),
    );
    if (!context.mounted) return;
    if (deleteNow == true) {
      await _deleteNow(context, ref, bike);
      return;
    }
    context.go('/home/profile');
  }

  /// Permanently deletes an (archived) bike after the type-the-name check.
  Future<void> _deleteNow(
      BuildContext context, WidgetRef ref, BikeEntity bike) async {
    final typed = await showDialog<bool>(
      context: context,
      builder: (_) => TypeToDeleteBikeDialog(bike: bike),
    );
    if (typed != true || !context.mounted) return;

    // Awaited, and errors surfaced: see BikeDao.delete for the deadlock that
    // used to make this fail silently.
    try {
      await ref.read(garageProvider.notifier).deleteArchivedNow(bike);
      if (context.mounted) context.go('/home/profile');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotDeleteThis(e))),
      );
    }
  }

  Future<void> _export(
      BuildContext context, WidgetRef ref, BikeEntity bike) async {
    try {
      await ref.read(bikeArchiveServiceProvider).shareExport(bike);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotExportBike(e))),
      );
    }
  }

  Future<void> _unarchive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(garageProvider.notifier).unarchiveBike(bikeId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.bikeBackGarage)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotUnarchiveThis(e))),
      );
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

/// First step of removing a bike. Archiving is the default and keeps
/// everything; each checkbox adds something to delete along with it. Pops an
/// [ArchiveCleanup], or null on cancel.
class ArchiveBikeDialog extends StatefulWidget {
  final BikeEntity bike;
  const ArchiveBikeDialog({super.key, required this.bike});

  @override
  State<ArchiveBikeDialog> createState() => _ArchiveBikeDialogState();
}

class _ArchiveBikeDialogState extends State<ArchiveBikeDialog> {
  bool _sharedRides = false;
  bool _miles = false;
  bool _serviceLogs = false;
  bool _fuelLogs = false;
  bool _photos = false;

  Widget _option(String key, String title, String hint, bool value,
      ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      key: Key(key),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(title, style: TextStyle(color: context.palette.textPrimary)),
      subtitle: Text(hint,
          style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(l10n.removeBikeQuestion(widget.bike.displayName),
          style: TextStyle(color: context.palette.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.archivingHidesThisBike,
                style: TextStyle(color: context.palette.textSecondary)),
            const SizedBox(height: 12),
            Text(l10n.archiveAlsoDelete,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary)),
            _option(
                'archive-opt-shared',
                l10n.archiveOptSharedRides,
                l10n.archiveOptSharedRidesHint,
                _sharedRides,
                (v) => setState(() => _sharedRides = v)),
            _option(
                'archive-opt-miles',
                l10n.archiveOptMiles,
                l10n.archiveOptMilesHint,
                _miles,
                (v) => setState(() => _miles = v)),
            _option(
                'archive-opt-logs',
                l10n.archiveOptServiceLogs,
                l10n.archiveOptServiceLogsHint,
                _serviceLogs,
                (v) => setState(() => _serviceLogs = v)),
            _option(
                'archive-opt-fuel',
                l10n.archiveOptFuelLogs,
                l10n.archiveOptFuelLogsHint,
                _fuelLogs,
                (v) => setState(() => _fuelLogs = v)),
            _option(
                'archive-opt-photos',
                l10n.archiveOptPhotos,
                l10n.archiveOptPhotosHint,
                _photos,
                (v) => setState(() => _photos = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelAction)),
        FilledButton(
          key: const Key('bike-archive'),
          onPressed: () => Navigator.pop(
            context,
            ArchiveCleanup(
              sharedRides: _sharedRides,
              miles: _miles,
              serviceLogs: _serviceLogs,
              fuelLogs: _fuelLogs,
              photos: _photos,
            ),
          ),
          child: Text(l10n.archiveBikeConfirm),
        ),
      ],
    );
  }
}

/// Shown right after archiving: when the bike will be permanently deleted,
/// with a way to keep a copy of its data or delete it right away. Pops true
/// for "Delete now".
class _ArchivedNoticeDialog extends StatelessWidget {
  final BikeEntity bike;
  final String purgeDate;
  final Future<void> Function() onExport;
  const _ArchivedNoticeDialog({
    required this.bike,
    required this.purgeDate,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(l10n.bikeArchivedTitle,
          style: TextStyle(color: context.palette.textPrimary)),
      content: Text(l10n.bikeArchivedBody(bike.displayName, purgeDate),
          style: TextStyle(color: context.palette.textSecondary)),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TextButton(
          key: const Key('bike-archived-delete-now'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.deleteNowAction,
              style: TextStyle(color: context.palette.danger)),
        ),
        TextButton(
          key: const Key('bike-archived-download'),
          onPressed: onExport,
          child: Text(l10n.downloadLocalCopy),
        ),
        FilledButton(
          key: const Key('bike-archived-ok'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

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
      backgroundColor: context.palette.surface,
      title: Text(context.l10n.deleteBikeQuestion,
          style: TextStyle(color: context.palette.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.deleteBikeConfirmBody(rides, expected),
              style: TextStyle(color: context.palette.textSecondary)),
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
            child: Text(context.l10n.cancelAction)),
        TextButton(
          key: const Key('bike-delete-confirm'),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: Text(context.l10n.delete,
              style: TextStyle(
                  color: _matches
                      ? context.palette.danger
                      : context.palette.textTertiary)),
        ),
      ],
    );
  }
}

/// "Service & maintenance" summary for one bike: the most urgent check and a
/// way into the full list. Bike detail had no maintenance entry point at all
/// (grill §3.2.3), so the only route in was the Maintenance tab with
/// whichever bike happened to be active.
class _ServiceCard extends ConsumerWidget {
  final String bikeId;
  const _ServiceCard({required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_outlined,
                  size: 20, color: context.palette.primary),
              const SizedBox(width: 8),
              Text(context.l10n.serviceMaintenance,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          NextDueLine(bikeId: bikeId, fontSize: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () =>
                    context.push('/home/maintenance/add?bikeId=$bikeId'),
                child: Text(context.l10n.logVisitTitle),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () =>
                    context.push('/home/maintenance?bikeId=$bikeId'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(context.l10n.viewAll),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fuel summary for one bike: average km/L and the last fill-up, with a way
/// to log one and into the full fuel log.
class _FuelCard extends ConsumerWidget {
  final String bikeId;
  const _FuelCard({required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logs = ref.watch(fuelLogsProvider(bikeId)).valueOrNull;
    final summary = ref.watch(fuelSummaryProvider(bikeId));
    final last = logs?.firstOrNull;
    final String line;
    if (last == null) {
      line = l10n.fuelCardNone;
    } else if (summary?.avgKmPerLiter != null) {
      line = l10n.fuelCardSummary(summary!.avgKmPerLiter!.toStringAsFixed(1),
          shortDate(context, last.filledAt));
    } else {
      line = l10n.fuelCardLastOnly(shortDate(context, last.filledAt));
    }
    return Container(
      key: const Key('bikeFuelCard'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_gas_station_outlined,
                  size: 20, color: context.palette.primary),
              const SizedBox(width: 8),
              Text(l10n.fuelTitle,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(line,
              style: TextStyle(
                  fontSize: 14, color: context.palette.textSecondary)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () =>
                    context.push('/home/maintenance/fuel/add?bikeId=$bikeId'),
                child: Text(l10n.fuelAddTitle),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () =>
                    context.push('/home/maintenance/fuel?bikeId=$bikeId'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(l10n.viewAll),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
