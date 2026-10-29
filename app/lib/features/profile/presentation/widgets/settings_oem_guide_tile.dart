import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../ride/presentation/screens/oem_guide_screen.dart';
import 'settings_link_tile.dart';

/// Settings → Ride tracking: "Rides keep stopping?" reopens the battery guide
/// after the one-time offer was dismissed. Only on brands the guide covers.
class SettingsOemGuideTile extends StatefulWidget {
  const SettingsOemGuideTile({
    super.key,
    @visibleForTesting this.brandLookup = currentOemBrand,
  });

  final Future<OemBrand?> Function() brandLookup;

  @override
  State<SettingsOemGuideTile> createState() => _SettingsOemGuideTileState();
}

class _SettingsOemGuideTileState extends State<SettingsOemGuideTile> {
  late final Future<OemBrand?> _brand = widget.brandLookup();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OemBrand?>(
      future: _brand,
      builder: (context, snap) {
        final brand = snap.data;
        if (brand == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SettingsLinkTile(
            icon: Icons.battery_alert_outlined,
            title: context.l10n.oemGuideSettingsTitle,
            subtitle: context.l10n.oemGuideSettingsSubtitle(brand.label),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => OemGuideScreen(brand: brand))),
          ),
        );
      },
    );
  }
}
