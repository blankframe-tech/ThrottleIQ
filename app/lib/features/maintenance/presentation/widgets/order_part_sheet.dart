import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../service_type_l10n.dart';
import 'edit_maintenance_check_sheet.dart' show iconForServiceType;

/// Checks that are a consumable or part a rider can actually buy. Pure
/// inspections/adjustments (chain tension, valve clearance, suspension, fuel,
/// custom) have nothing to order.
const _orderableTypes = {
  ServiceType.oilChange,
  ServiceType.oilFilter,
  ServiceType.airFilter,
  ServiceType.chain,
  ServiceType.tire,
  ServiceType.radiatorCoolant,
  ServiceType.frontDiscPads,
  ServiceType.rearDrumPads,
  ServiceType.brakeFluid,
  ServiceType.sparkPlug,
  ServiceType.battery,
  ServiceType.clutchCable,
  ServiceType.throttleCables,
  ServiceType.brakeRotors,
  ServiceType.forkSeals,
  ServiceType.wheelBearings,
  ServiceType.driveBelt,
};

bool isOrderable(ServiceType type) => _orderableTypes.contains(type);

/// DEMO ONLY — cash-on-delivery order form for a part that is running low.
/// Nothing is sent, stored or charged; the UI says so up front and again on
/// the confirmation.
class OrderPartSheet extends StatefulWidget {
  final ServiceType serviceType;

  const OrderPartSheet({super.key, required this.serviceType});

  static Future<void> show(BuildContext context, ServiceType serviceType) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderPartSheet(serviceType: serviceType),
    );
  }

  @override
  State<OrderPartSheet> createState() => _OrderPartSheetState();
}

class _OrderPartSheetState extends State<OrderPartSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  int _qty = 1;
  bool _placed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _place() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _placed = true);
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.partOrderRequired : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final part = widget.serviceType.localizedLabel(l10n);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(context.shape.radiusXl)),
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingMd, 14,
          AppDimensions.paddingMd, bottomInset + AppDimensions.paddingMd),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconForServiceType(widget.serviceType),
                      color: palette.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _placed ? l10n.partOrderPlacedTitle : l10n.partOrderTitle(part),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TestingNotice(
                text: _placed
                    ? l10n.partOrderPlacedBody
                    : l10n.partOrderTestingNotice),
            const SizedBox(height: 14),
            if (_placed)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.done),
                ),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l10n.partOrderName),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration:
                          InputDecoration(labelText: l10n.partOrderPhone),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration:
                          InputDecoration(labelText: l10n.partOrderAddress),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(l10n.partOrderQuantity,
                            style: TextStyle(color: palette.textSecondary)),
                        const Spacer(),
                        IconButton(
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_qty',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        IconButton(
                          onPressed: _qty < 10 ? () => setState(() => _qty++) : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 16, color: palette.textSecondary),
                        const SizedBox(width: 6),
                        Text(l10n.partOrderCod,
                            style: TextStyle(
                                fontSize: 13, color: palette.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _place,
                        child: Text(l10n.partOrderPlace),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TestingNotice extends StatelessWidget {
  final String text;
  const _TestingNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final color = context.palette.attention;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.shape.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
