import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'maintenance_format.dart';

/// One logged service in the history list, with delete.
class MaintenanceLogTile extends ConsumerWidget {
  final MaintenanceEntity log;
  final bool imperial;
  const MaintenanceLogTile({super.key, required this.log, required this.imperial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.localizedDisplayLabel(context.l10n), style: display(context, 14, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text(
                  '${formatServiceDate(log.date)} · ${distLabel(log.odometerKm, imperial)}'
                  '${log.cost != null ? ' · ৳${log.cost!.toStringAsFixed(0)}' : ''}',
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(log.notes!,
                      style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.delete,
            icon: Icon(Icons.delete_outline, color: context.palette.textTertiary, size: 18),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ctx.palette.surface,
                  title: Text(ctx.l10n.deleteLog, style: display(ctx, 16)),
                  content: Text(
                    ctx.l10n.sureWantDeleteThis(log.localizedDisplayLabel(ctx.l10n)),
                    style: TextStyle(fontSize: 13, color: ctx.palette.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(ctx.l10n.cancelAction,
                          style: TextStyle(color: ctx.palette.textTertiary)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ctx.palette.danger),
                      child: Text(ctx.l10n.delete),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref
                    .read(maintenanceProvider(log.bikeId).notifier)
                    .deleteLog(log.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
