import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/maintenance_profile.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import 'forecast_text.dart';

/// Tax token, insurance, fitness, registration and licence expiry, with the
/// same reminders as service items (Bajaj Connect and the Royal Enfield app
/// both do this — and BD riders get stopped for papers).
class PaperworkCard extends ConsumerWidget {
  final String bikeId;
  const PaperworkCard({super.key, required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final papers = ref.watch(paperworkProvider(bikeId)).valueOrNull ?? const [];
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: EditorialLabel(l10n.paperworkTitle)),
            TextButton.icon(
              onPressed: () => PaperworkSheet.show(context, bikeId: bikeId),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.addAction, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (papers.isEmpty)
          Text(l10n.paperworkEmpty,
              style: TextStyle(fontSize: 12, color: context.palette.textTertiary))
        else
          EditorialCard(
            radius: context.shape.radiusLg,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final p in papers)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.description_outlined,
                        color: _color(context, p.daysLeft(now))),
                    title: Text(paperworkLabel(p.kind, l10n),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      p.daysLeft(now) < 0
                          ? l10n.paperworkExpiredOn(longDate(context, p.expiresOn))
                          : l10n.paperworkExpiresOn(
                              longDate(context, p.expiresOn), p.daysLeft(now)),
                      style: TextStyle(
                          fontSize: 12, color: _color(context, p.daysLeft(now))),
                    ),
                    onTap: () =>
                        PaperworkSheet.show(context, bikeId: bikeId, existing: p),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Color _color(BuildContext context, int days) => days < 0
      ? context.palette.danger
      : days <= PaperworkEntity.warnDays
          ? context.palette.attention
          : context.palette.textSecondary;
}

class PaperworkSheet extends ConsumerStatefulWidget {
  final String bikeId;
  final PaperworkEntity? existing;
  const PaperworkSheet({super.key, required this.bikeId, this.existing});

  static Future<void> show(BuildContext context,
          {required String bikeId, PaperworkEntity? existing}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.palette.surface,
        builder: (_) => PaperworkSheet(bikeId: bikeId, existing: existing),
      );

  @override
  ConsumerState<PaperworkSheet> createState() => _PaperworkSheetState();
}

class _PaperworkSheetState extends ConsumerState<PaperworkSheet> {
  late PaperworkKind _kind;
  DateTime? _expires;

  @override
  void initState() {
    super.initState();
    _kind = widget.existing?.kind ?? PaperworkKind.taxToken;
    _expires = widget.existing?.expiresOn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notifier = ref.read(paperworkProvider(widget.bikeId).notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.paperworkTitle, style: display(context, 18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in PaperworkKind.values)
                  ChoiceChip(
                    label: Text(paperworkLabel(k, l10n)),
                    selected: _kind == k,
                    onSelected: widget.existing != null
                        ? null
                        : (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 18),
              label: Text(_expires == null
                  ? l10n.paperworkPickExpiry
                  : l10n.paperworkExpiryValue(longDate(context, _expires!))),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expires ?? DateTime(now.year + 1, now.month, now.day),
                  firstDate: _expires != null && _expires!.year < now.year - 5
                      ? _expires!
                      : DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 15),
                );
                if (picked != null) setState(() => _expires = picked);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton(
                    onPressed: () async {
                      await notifier.remove(_kind);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(l10n.delete,
                        style: TextStyle(color: context.palette.danger)),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _expires == null
                      ? null
                      : () async {
                          await notifier.upsert(PaperworkEntity(
                            bikeId: widget.bikeId,
                            kind: _kind,
                            expiresOn: _expires!,
                          ));
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  child: Text(l10n.safeQrSaveAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
