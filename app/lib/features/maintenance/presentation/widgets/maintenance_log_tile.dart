import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/bike_image_resolver.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/service_visit.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'forecast_text.dart';
import 'maintenance_format.dart';

/// One service visit in history: when, where, what was done, what it cost.
/// Tap to edit; the menu deletes the whole visit.
class VisitTile extends ConsumerWidget {
  final ServiceVisit visit;
  final bool imperial;
  const VisitTile({super.key, required this.visit, required this.imperial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final v = visit;
    final meta = [
      longDate(context, v.date),
      distLabelLong(v.odometerKm, imperial),
      if ((v.shopName ?? '').isNotEmpty) v.shopName!,
      if (v.shopKind != null && (v.shopName ?? '').isEmpty)
        shopKindLabel(v.shopKind!, l10n),
    ].join(' · ');
    final receipt = BikeImageResolver.resolvePathSync(v.receiptPath);
    final hasReceipt = receipt != null;

    return EditorialCard(
      key: Key('visit_${v.id}'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      onTap: () => context.push(
          '/home/maintenance/add?bikeId=${v.bikeId}&visitId=${Uri.encodeComponent(v.id)}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v.freeServiceNumber != null
                            ? l10n.freeServiceN(v.freeServiceNumber!)
                            : (v.items.length == 1
                                ? v.items.first.localizedDisplayLabel(l10n)
                                : l10n.serviceVisit),
                        style: display(context, 14, letterSpacing: 0),
                      ),
                    ),
                    if (v.totalCost != null)
                      Text('৳${formatTaka(v.totalCost!)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(meta,
                    style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                if (v.items.length > 1) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final i in v.items)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.palette.surfaceVariant,
                            borderRadius:
                                BorderRadius.circular(context.shape.radiusSm),
                          ),
                          child: Text(i.localizedDisplayLabel(l10n),
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: context.palette.textSecondary)),
                        ),
                    ],
                  ),
                ],
                if ((v.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(v.notes!,
                      style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                ],
              ],
            ),
          ),
          if (hasReceipt) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(context.shape.radiusSm),
              child: Image.file(File(receipt), width: 40, height: 40, fit: BoxFit.cover),
            ),
          ],
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: context.palette.textTertiary),
            onSelected: (choice) async {
              if (choice != 'delete') return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ctx.palette.surface,
                  title: Text(ctx.l10n.deleteVisitTitle, style: display(ctx, 16)),
                  content: Text(ctx.l10n.deleteVisitBody(v.items.length),
                      style: TextStyle(fontSize: 13, color: ctx.palette.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(ctx.l10n.cancelAction),
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
              if (ok == true) {
                await ref
                    .read(maintenanceProvider(v.bikeId).notifier)
                    .deleteVisit(v.id);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'delete', child: Text(ctx.l10n.delete)),
            ],
          ),
        ],
      ),
    );
  }
}
