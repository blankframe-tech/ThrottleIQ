import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/crash_detection_settings.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/entities/impact_event_types.dart';

/// In-ride pill (top-left of the cockpit): where the phone is right now —
/// on a mount, in a pocket or in a bag.
///
/// Where the phone sits changes what a fall looks like to the sensors (a
/// mount shakes with the engine and lies down with the bike; a pocket rides
/// with the body). Riders swap mid-ride, so it lives in the cockpit and is
/// read at impact time. Remembered between rides; skipping it leaves "unknown".
class PhonePlacementSelector extends ConsumerWidget {
  const PhonePlacementSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(phonePlacementProvider);
    final l10n = context.l10n;
    final palette = context.palette;
    final options = [
      (PhonePlacement.mount, l10n.phonePlacementMount, Icons.smartphone),
      (PhonePlacement.pocket, l10n.phonePlacementPocket, Icons.checkroom),
      (PhonePlacement.bag, l10n.phonePlacementBag, Icons.backpack_outlined),
    ];
    final current = options.where((o) => o.$1 == selected).firstOrNull;
    return PopupMenuButton<PhonePlacement>(
      key: const Key('phone_placement_toggle'),
      tooltip: l10n.phonePlacementLabel,
      onSelected: (p) => ref.read(phonePlacementProvider.notifier).choose(p),
      itemBuilder: (_) => [
        for (final (placement, label, icon) in options)
          CheckedPopupMenuItem(
            key: Key('phone_placement_${placement.wire}'),
            value: placement,
            checked: selected == placement,
            child: Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ]),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(current?.$3 ?? Icons.phone_android,
              size: 18, color: palette.textPrimary),
          const SizedBox(width: 6),
          Text(current?.$2 ?? l10n.phonePlacementLabel,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary)),
        ]),
      ),
    );
  }
}
