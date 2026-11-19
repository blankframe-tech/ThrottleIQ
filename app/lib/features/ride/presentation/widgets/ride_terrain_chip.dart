import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/entities/impact_event_types.dart';
import '../providers/ride_recording_provider.dart';

/// Cockpit toggle next to the phone placement pill: Off-road makes crash
/// detection read jump landings as jumps. Off at every ride start.
class RideTerrainChip extends ConsumerWidget {
  const RideTerrainChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(rideTerrainProvider) == RideTerrain.offRoad;
    final palette = context.palette;
    final l10n = context.l10n;
    // Icon-only: the top cockpit row has no width to spare.
    return Semantics(
      button: true,
      selected: on,
      label: l10n.rideTerrainOffRoad,
      child: Tooltip(
        message: l10n.rideTerrainTooltip,
        child: InkWell(
          key: const Key('ride_terrain_toggle'),
          customBorder: const CircleBorder(),
          onTap: () => ref
              .read(rideRecordingProvider.notifier)
              .setTerrain(on ? RideTerrain.road : RideTerrain.offRoad),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: on
                  ? palette.primary.withValues(alpha: 0.9)
                  : palette.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: on ? palette.primary : palette.border),
            ),
            child: Icon(Icons.terrain,
                size: 20, color: on ? Colors.white : palette.textPrimary),
          ),
        ),
      ),
    );
  }
}
