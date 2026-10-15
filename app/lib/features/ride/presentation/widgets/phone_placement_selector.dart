import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/crash_detection_settings.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/entities/impact_event_types.dart';

/// Ride start → "Phone: On a mount · In a pocket · In a bag".
///
/// Where the phone sits changes what a fall looks like to the sensors (a
/// mount shakes with the engine and lies down with the bike; a pocket rides
/// with the body), so every ride and impact records it. Remembered between
/// rides, so it's a tap only when it changes; skipping it leaves "unknown".
class PhonePlacementSelector extends ConsumerStatefulWidget {
  const PhonePlacementSelector({super.key});

  @override
  ConsumerState<PhonePlacementSelector> createState() =>
      _PhonePlacementSelectorState();
}

class _PhonePlacementSelectorState
    extends ConsumerState<PhonePlacementSelector> {
  // Collapsed by default: the choice is remembered, so it's rarely a tap.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(phonePlacementProvider);
    final l10n = context.l10n;
    final palette = context.palette;
    final options = [
      (PhonePlacement.mount, l10n.phonePlacementMount, Icons.smartphone),
      (PhonePlacement.pocket, l10n.phonePlacementPocket, Icons.checkroom),
      (PhonePlacement.bag, l10n.phonePlacementBag, Icons.backpack_outlined),
    ];
    final current = [
      for (final o in options)
        if (o.$1 == selected) o.$2
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('phone_placement_toggle'),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    current.isEmpty
                        ? l10n.phonePlacementLabel
                        : '${l10n.phonePlacementLabel}: ${current.first}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary),
                  ),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: palette.textSecondary),
              ],
            ),
          ),
        ),
        if (_open) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final (placement, label, icon) in options)
                ChoiceChip(
                  key: Key('phone_placement_${placement.wire}'),
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  selected: selected == placement,
                  onSelected: (_) => ref
                      .read(phonePlacementProvider.notifier)
                      .choose(placement),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.phonePlacementHint,
              style: TextStyle(fontSize: 11.5, color: palette.textTertiary)),
        ],
      ],
    );
  }
}
