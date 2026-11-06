import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../ride/presentation/screens/oem_guide_screen.dart';
import 'settings_link_tile.dart';

/// Settings → Ride tracking: "Rides keep stopping?" reopens the battery guide
/// after the one-time offer was dismissed. Any phone; unknown makers get the
/// generic steps.
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
    // Battery killers are an Android thing.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<OemBrand?>(
      future: _brand,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final brand = snap.data;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SettingsLinkTile(
            icon: Icons.battery_alert_outlined,
            title: context.l10n.oemGuideSettingsTitle,
            subtitle: brand == null
                ? context.l10n.oemGuideSettingsSubtitleGeneric
                : context.l10n.oemGuideSettingsSubtitle(brand.label),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => OemGuideScreen(brand: brand))),
          ),
        );
      },
    );
  }
}
