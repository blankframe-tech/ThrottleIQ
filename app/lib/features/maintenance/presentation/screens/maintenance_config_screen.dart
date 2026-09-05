import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';

class MaintenanceConfigScreen extends ConsumerStatefulWidget {
  final String bikeId;
  final bool isFirstTime;

  const MaintenanceConfigScreen({
    super.key,
    required this.bikeId,
    this.isFirstTime = false,
  });

  @override
  ConsumerState<MaintenanceConfigScreen> createState() =>
      _MaintenanceConfigScreenState();
}

class _MaintenanceConfigScreenState
    extends ConsumerState<MaintenanceConfigScreen> {
  List<MaintenanceConfigEntity>? _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initItems());
  }

  void _initItems() {
    final asyncConfigs = ref.read(maintenanceConfigProvider(widget.bikeId));
    final configs = asyncConfigs.valueOrNull;
    if (configs != null && configs.isNotEmpty) {
      setState(() {
        _items = configs.map((c) => c.copyWith()).toList();
      });
    } else {
      // Fallback: build full catalog
      setState(() {
        _items = ServiceType.values
            .where((t) => t != ServiceType.custom)
            .map((t) => MaintenanceConfigEntity(
                  bikeId: widget.bikeId,
                  serviceType: t,
                  intervalKm: t.defaultIntervalKm,
                  isEnabled: t.isRecommendedDefault,
                ))
            .toList();
      });
    }
  }

  void _toggleItem(ServiceType type) {
    if (_items == null) return;
    setState(() {
      _items = _items!.map((item) {
        if (item.serviceType == type) {
          return item.copyWith(isEnabled: !item.isEnabled);
        }
        return item;
      }).toList();
    });
  }

  void _selectRecommended() {
    if (_items == null) return;
    setState(() {
      _items = _items!.map((item) {
        return item.copyWith(isEnabled: item.serviceType.isRecommendedDefault);
      }).toList();
    });
  }

  void _selectAll() {
    if (_items == null) return;
    setState(() {
      _items = _items!.map((item) => item.copyWith(isEnabled: true)).toList();
    });
  }

  void _clearAll() {
    if (_items == null) return;
    setState(() {
      _items = _items!.map((item) => item.copyWith(isEnabled: false)).toList();
    });
  }

  Future<void> _editInterval(MaintenanceConfigEntity item) async {
    final ctrl = TextEditingController(text: item.intervalKm.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Set ${item.serviceType.label} Interval', style: display(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the recommended service interval in kilometers according to your motorcycle manual.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Service Interval (km)',
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [1000, 1500, 3000, 5000, 10000, 15000].map((preset) {
                return ActionChip(
                  label: Text('${preset.toString()} km',
                      style: const TextStyle(fontSize: 11)),
                  onPressed: () => ctrl.text = preset.toString(),
                  backgroundColor: AppColors.surfaceVariant,
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _items = _items!.map((c) {
          if (c.serviceType == item.serviceType) {
            return c.copyWith(intervalKm: result);
          }
          return c;
        }).toList();
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (_items == null) return;
    setState(() => _saving = true);

    await ref
        .read(maintenanceConfigProvider(widget.bikeId).notifier)
        .saveConfigs(_items!);

    if (!mounted) return;

    if (widget.isFirstTime) {
      context.go('/home/maintenance?bikeId=${widget.bikeId}');
    } else {
      context.pop();
    }
  }

  IconData _iconForService(ServiceType type) {
    switch (type) {
      case ServiceType.oilChange:
      case ServiceType.oilFilter:
        return Icons.opacity;
      case ServiceType.airFilter:
        return Icons.air;
      case ServiceType.chain:
      case ServiceType.chainTension:
        return Icons.link;
      case ServiceType.tire:
        return Icons.tire_repair;
      case ServiceType.frontDiscPads:
      case ServiceType.rearDrumPads:
      case ServiceType.brakeFluid:
      case ServiceType.brakeRotors:
        return Icons.disc_full;
      case ServiceType.sparkPlug:
        return Icons.electric_bolt;
      case ServiceType.battery:
        return Icons.battery_charging_full;
      case ServiceType.radiatorCoolant:
        return Icons.water_drop;
      case ServiceType.clutchCable:
      case ServiceType.throttleCables:
        return Icons.tune;
      case ServiceType.valveClearance:
        return Icons.build;
      case ServiceType.suspension:
      case ServiceType.forkSeals:
        return Icons.vertical_align_center;
      case ServiceType.wheelBearings:
      case ServiceType.driveBelt:
        return Icons.album;
      case ServiceType.custom:
        return Icons.handyman;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bikes = ref.watch(garageProvider).valueOrNull ?? [];
    final bike = bikes.where((b) => b.id == widget.bikeId).firstOrNull;
    final bikeName = bike?.displayName ?? 'Your Motorcycle';

    final items = _items;
    final enabledCount = items?.where((i) => i.isEnabled).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isFirstTime ? 'Setup Maintenance' : 'Edit Tracked Checks'),
        actions: [
          if (widget.isFirstTime)
            TextButton(
              onPressed: _saving ? null : _saveAndContinue,
              child: Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
            ),
        ],
      ),
      body: items == null
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.paddingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header prompt card
                        EditorialCard(
                          radius: AppDimensions.radiusLg,
                          padding: const EdgeInsets.all(16),
                          borderColor: AppColors.primary.withValues(alpha: 0.3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.two_wheeler,
                                        color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'What would you like to track for $bikeName?',
                                      style: display(15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select the components you want ThrottleIQ to monitor. We will calculate wear based on your odometer and notify you before services are due.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quick selection actions
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _selectRecommended,
                              icon: const Icon(Icons.recommend, size: 16),
                              label: const Text('Recommended',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _selectAll,
                              child: const Text('Select All',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: _clearAll,
                              child: Text('Clear',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Grouped Categories
                        for (final category in MaintenanceCategory.values) ...[
                          _buildCategorySection(category, items),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom Action Bar
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveAndContinue,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                enabledCount > 0
                                    ? 'Track $enabledCount Checks'
                                    : 'Save Preferences',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategorySection(
      MaintenanceCategory category, List<MaintenanceConfigEntity> allItems) {
    final categoryItems =
        allItems.where((i) => i.serviceType.category == category).toList();
    if (categoryItems.isEmpty) return const SizedBox.shrink();

    final activeInCategory = categoryItems.where((i) => i.isEnabled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EditorialLabel(category.label),
            Text(
              '$activeInCategory of ${categoryItems.length} active',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in categoryItems) ...[
          _buildCheckTile(item),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildCheckTile(MaintenanceConfigEntity item) {
    final isEnabled = item.isEnabled;

    return Container(
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.surfaceVariant
            : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleItem(item.serviceType),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: isEnabled,
                onChanged: (_) => _toggleItem(item.serviceType),
                activeColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Icon(
                _iconForService(item.serviceType),
                size: 20,
                color: isEnabled ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.serviceType.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                        color: isEnabled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.serviceType.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _editInterval(item),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.intervalKm.toStringAsFixed(0)} km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.edit_outlined,
                          size: 11, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
