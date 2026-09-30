import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'edit_maintenance_check_sheet.dart';

/// First-run picker shown until the rider saves which checks to track.
class MaintenanceFirstTimeCards extends ConsumerStatefulWidget {
  final BikeEntity bike;
  final bool imperial;

  const MaintenanceFirstTimeCards({
    super.key,
    required this.bike,
    required this.imperial,
  });

  @override
  ConsumerState<MaintenanceFirstTimeCards> createState() =>
      _FirstTimeMaintenanceCardsState();
}

class _FirstTimeMaintenanceCardsState
    extends ConsumerState<MaintenanceFirstTimeCards> {
  static const _catalogTypes = [
    ServiceType.fuel,
    ServiceType.oilChange,
    ServiceType.chain,
    ServiceType.tire,
    ServiceType.frontDiscPads,
    ServiceType.airFilter,
    ServiceType.battery,
    ServiceType.sparkPlug,
  ];

  late List<MaintenanceConfigEntity> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(maintenanceConfigProvider(widget.bike.id)).valueOrNull ?? [];
    final map = {for (final e in existing) e.serviceType: e};

    _items = _catalogTypes.map((type) {
      if (map.containsKey(type)) {
        return map[type]!;
      }
      final isEssential = type == ServiceType.fuel ||
          type == ServiceType.oilChange ||
          type == ServiceType.chain ||
          type == ServiceType.tire;
      return MaintenanceConfigEntity(
        bikeId: widget.bike.id,
        serviceType: type,
        intervalKm: type.defaultIntervalKm,
        isEnabled: isEssential,
      );
    }).toList();
  }

  void _toggle(ServiceType type) {
    setState(() {
      _items = _items.map((it) {
        if (it.serviceType == type) {
          return it.copyWith(isEnabled: !it.isEnabled);
        }
        return it;
      }).toList();
    });
  }

  void _selectEssentials() {
    setState(() {
      _items = _items.map((it) {
        final isEssential = it.serviceType == ServiceType.fuel ||
            it.serviceType == ServiceType.oilChange ||
            it.serviceType == ServiceType.chain ||
            it.serviceType == ServiceType.tire;
        return it.copyWith(isEnabled: isEssential);
      }).toList();
    });
  }

  void _selectAll() {
    setState(() {
      _items = _items.map((it) => it.copyWith(isEnabled: true)).toList();
    });
  }

  void _clearAll() {
    setState(() {
      _items = _items.map((it) => it.copyWith(isEnabled: false)).toList();
    });
  }

  Future<void> _editItem(MaintenanceConfigEntity item) async {
    final updated = await EditMaintenanceCheckSheet.show(
      context,
      config: item,
      persistImmediately: false,
    );
    if (updated != null && mounted) {
      setState(() {
        _items = _items.map((it) {
          if (it.serviceType == updated.serviceType) {
            return updated;
          }
          return it;
        }).toList();
      });
    }
  }

  Future<void> _startTracking() async {
    setState(() => _saving = true);
    await ref
        .read(maintenanceConfigProvider(widget.bike.id).notifier)
        .saveConfigs(_items);
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _items.where((i) => i.isEnabled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome card
        EditorialCard(
          radius: context.shape.radiusLg,
          padding: const EdgeInsets.all(16),
          borderColor: context.palette.primary.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.palette.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.two_wheeler,
                        color: context.palette.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.whatWouldLikeMaintain,
                      style: display(context, 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.notEveryoneWantsTrack(widget.bike.displayName),
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: Icon(Icons.star_outline,
                        size: 14, color: context.palette.primary),
                    label: Text(context.l10n.essentials4,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: _selectEssentials,
                    backgroundColor: context.palette.surfaceVariant,
                    side: BorderSide(color: context.palette.border),
                  ),
                  ActionChip(
                    avatar: Icon(Icons.done_all,
                        size: 14, color: context.palette.textSecondary),
                    label: Text(context.l10n.all8Items,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: _selectAll,
                    backgroundColor: context.palette.surfaceVariant,
                    side: BorderSide(color: context.palette.border),
                  ),
                  ActionChip(
                    avatar: Icon(Icons.clear,
                        size: 14, color: context.palette.textTertiary),
                    label: Text(context.l10n.clear,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: _clearAll,
                    backgroundColor: context.palette.surfaceVariant,
                    side: BorderSide(color: context.palette.border),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Curated Setup Cards
        for (final item in _items) ...[
          _buildFirstTimeCard(item),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),

        // Action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _startTracking,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              _saving
                  ? context.l10n.savingPreferences
                  : (enabledCount > 0
                      ? context.l10n.startTrackingItems(enabledCount)
                      : context.l10n.savePreferences),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push(
                '/home/maintenance/configure?bikeId=${widget.bike.id}'),
            icon: const Icon(Icons.tune, size: 14),
            label: Text(
              context.l10n.seeAll20Checks,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstTimeCard(MaintenanceConfigEntity item) {
    final isSelected = item.isEnabled;
    final icon = iconForServiceType(item.serviceType);

    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: isSelected
          ? context.palette.primary.withValues(alpha: 0.5)
          : context.palette.border,
      color: isSelected
          ? context.palette.surfaceVariant.withValues(alpha: 0.7)
          : context.palette.surface.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () => _toggle(item.serviceType),
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggle(item.serviceType),
                  activeColor: context.palette.primary,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? context.palette.primary : context.palette.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.serviceType.localizedLabel(context.l10n),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? context.palette.textPrimary
                              : context.palette.textTertiary,
                        ),
                      ),
                      Text(
                        item.serviceType.localizedDescription(context.l10n),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.palette.textTertiary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _editItem(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius:
                          BorderRadius.circular(context.shape.radiusFull),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.intervalKm.toStringAsFixed(0)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? context.palette.primary
                                : context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.edit_outlined,
                            size: 11,
                            color: isSelected
                                ? context.palette.primary
                                : context.palette.textTertiary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 12, color: context.palette.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.notes!.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

