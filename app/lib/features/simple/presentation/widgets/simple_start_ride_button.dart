import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../ride/presentation/widgets/hold_to_start_button.dart';
import '../../../ride/presentation/widgets/recording_gate.dart';

/// The Record tab's flow (record_screen.dart): start, then the cockpit, else
/// say why not. Simple Home's ring and the empty Rides tab both use it.
Future<void> startSimpleRide(
    BuildContext context, WidgetRef ref, String bikeId) async {
  await ref.read(rideRecordingProvider.notifier).startRide(bikeId: bikeId);
  if (!context.mounted) return;
  final result = ref.read(rideRecordingProvider);
  if (result.status == RecordingStatus.active) {
    context.go('/ride/active');
  } else {
    showRecordingBlockedSnackBar(context, result);
  }
}

/// Simple Home's start control: the full app's round hold-to-start ring (an
/// accidental brush can't start a ride), or the way back to a running ride.
class SimpleStartRideButton extends ConsumerWidget {
  const SimpleStartRideButton({super.key, required this.bike});

  final BikeEntity bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(rideRecordingProvider.select((s) => s.status));
    if (status == RecordingStatus.active || status == RecordingStatus.paused) {
      return FilledButton.icon(
        key: const Key('simple_home_open_ride'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: () => context.go('/ride/active'),
        icon: const Icon(Icons.navigation),
        label: Text(context.l10n.simpleHomeOpenRide),
      );
    }
    return HoldToStartButton(
      key: const Key('simple_home_start_ride'),
      busy: status == RecordingStatus.starting,
      onStart: () => startSimpleRide(context, ref, bike.id),
    );
  }
}
