import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_modules.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/root_messenger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../poi_directory/data/repositories/place_repository.dart';
import '../../../poi_directory/data/utils/geohash_utils.dart';
import '../../../poi_directory/domain/entities/place_entity.dart';
import '../../../poi_directory/presentation/providers/places_provider.dart';
import '../providers/live_ride_places_provider.dart';
import '../providers/parking_pin_provider.dart';
import '../providers/ride_recording_provider.dart';

/// Stored verbatim in the public place doc, so deliberately not localized:
/// a Bangla rider's report must not reach English riders in Bangla.
const copCheckpointPlaceName = 'Cop checkpoint';

enum _RideAction {
  copCheckpoint,
  parkingPin,
  minimize,
}

enum _CheckpointDuration {
  oneDay,
  permanent,
}

class RideActionsMenu extends ConsumerWidget {
  final PlaceRepository? placeRepository;

  const RideActionsMenu({super.key, this.placeRepository});

  PlaceRepository get _repo => placeRepository ?? PlaceRepository();

  Future<void> _handleCopCheckpoint(BuildContext context, WidgetRef ref) async {
    final position = ref.read(rideRecordingProvider).currentPosition;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noGpsFixYet)),
      );
      return;
    }

    final choice = await showModalBottomSheet<_CheckpointDuration>(
      context: context,
      backgroundColor: context.palette.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(sheetContext.l10n.checkpointExpiresInDay),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_CheckpointDuration.oneDay),
            ),
            ListTile(
              title: Text(sheetContext.l10n.checkpointPermanent),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_CheckpointDuration.permanent),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    final now = DateTime.now();
    final expiresAt = choice == _CheckpointDuration.oneDay
        ? now.add(const Duration(hours: 24))
        : null;
    final uid = ref.read(currentUserProvider)?.uid ?? '';
    final geohash = GeohashUtils.encode(position.latitude, position.longitude);

    final place = PlaceEntity(
      id: '',
      name: copCheckpointPlaceName,
      category: PlaceCategory.police,
      latitude: position.latitude,
      longitude: position.longitude,
      geohash: geohash,
      address: '',
      createdBy: uid,
      createdAt: now,
      expiresAt: expiresAt,
    );

    // Not awaited: add() completes only on the server's ack, which in a dead
    // zone can be minutes away. Firestore has already queued the write
    // locally, so confirm now and only speak up again if it's rejected. The
    // rider may have minimized by then, hence the root messenger.
    final failedText = context.l10n.checkpointSaveFailed;
    unawaited(_repo.addPlace(place, untilAcked: true).then((_) {
      ref.invalidate(nearbyPlacesProvider);
    }).catchError((Object _) {
      rootScaffoldMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(failedText)));
    }));
    ref.read(liveRidePlacesProvider.notifier).add(place);
    ref.invalidate(nearbyPlacesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.checkpointSaved)),
    );
  }

  Future<void> _handleParkingPin(BuildContext context, WidgetRef ref) async {
    final ride = ref.read(rideRecordingProvider);
    // Mid pause/resume, pauseRide() would no-op and the pin would be cleared
    // the moment the resume lands. The menu is one tap away once it settles.
    if (ride.transitionPending) return;
    final position = ride.currentPosition;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noGpsFixYet)),
      );
      return;
    }

    await ref.read(parkingPinProvider.notifier).drop(position);
    if (ride.status == RecordingStatus.active) {
      await ref.read(rideRecordingProvider.notifier).pauseRide();
      // A refused pause leaves the status unchanged, so the provider's own
      // listener never fires; don't leave a pin on an active ride.
      if (ref.read(rideRecordingProvider).status != RecordingStatus.paused) {
        await ref.read(parkingPinProvider.notifier).clear();
      }
    }
  }

  void _handleMinimize(BuildContext context, WidgetRef ref) {
    final places = ref.read(appModulesProvider).places;
    context.go(places ? '/home/places' : '/home/stats');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_RideAction>(
      tooltip: context.l10n.rideActionsTooltip,
      icon: Icon(Icons.more_vert, color: context.palette.textPrimary),
      onSelected: (action) {
        switch (action) {
          case _RideAction.copCheckpoint:
            _handleCopCheckpoint(context, ref);
            break;
          case _RideAction.parkingPin:
            _handleParkingPin(context, ref);
            break;
          case _RideAction.minimize:
            _handleMinimize(context, ref);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _RideAction.copCheckpoint,
          child: Text(context.l10n.copCheckpointHere),
        ),
        PopupMenuItem(
          value: _RideAction.parkingPin,
          child: Text(context.l10n.parkingPinHere),
        ),
        PopupMenuItem(
          value: _RideAction.minimize,
          child: Text(context.l10n.minimizeRide),
        ),
      ],
    );
  }
}
