import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/sensor_constants.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../poi_directory/presentation/widgets/place_launch_actions.dart';
import '../providers/parking_pin_provider.dart';
import '../providers/ride_recording_provider.dart';

/// Pinned above the bottom nav on every shell screen while a ride records
/// with the cockpit minimized; tapping it goes back to `/ride/active`.
class RideInProgressBar extends ConsumerWidget {
  const RideInProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The crash countdown only renders in the cockpit, so a minimized rider
    // has to be taken there. Same flag the cockpit's overlay checks.
    ref.listen<bool>(
      rideRecordingProvider.select((s) => s.crashDetected),
      (previous, next) {
        if (SensorConstants.crashAlertsEnabled &&
            previous == false &&
            next == true) {
          context.go('/ride/active');
        }
      },
    );

    final (status, elapsedSeconds, distanceM) = ref.watch(
      rideRecordingProvider.select(
        (s) => (s.status, s.elapsed.inSeconds, s.distanceM),
      ),
    );

    if (status != RecordingStatus.active && status != RecordingStatus.paused) {
      return const SizedBox.shrink();
    }

    final parkingPin =
        status == RecordingStatus.paused ? ref.watch(parkingPinProvider) : null;

    final distanceStr = SpeedFormatter.distanceKm(distanceM);
    final durationStr =
        SpeedFormatter.durationFromDuration(Duration(seconds: elapsedSeconds));
    final isPaused = status == RecordingStatus.paused;
    final text = isPaused
        ? context.l10n.ridePausedBar(distanceStr, durationStr)
        : context.l10n.rideRecordingBar(distanceStr, durationStr);
    final dotColor =
        isPaused ? context.palette.warning : context.palette.danger;

    return Material(
      color: context.palette.surface,
      child: InkWell(
        onTap: () => context.go('/ride/active'),
        child: Semantics(
          button: true,
          label: text,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.palette.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (parkingPin != null) ...[
                  TextButton(
                    onPressed: () => PlaceLaunchActions.openDirectionsTo(
                      context,
                      latitude: parkingPin.point.latitude,
                      longitude: parkingPin.point.longitude,
                      label: context.l10n.parkingPinHere,
                    ),
                    child: Text(context.l10n.directionsToBike),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
