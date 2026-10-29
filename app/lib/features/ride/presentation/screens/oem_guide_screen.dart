import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';

/// Phone makers whose battery savers stop ThrottleIQ mid-ride unless the
/// rider changes a few settings (critique B5). [autostart] are the vendor
/// autostart screens dontkillmyapp.com points to, tried in order; [slug] is
/// that site's page for the brand.
enum OemBrand {
  xiaomi('Xiaomi', 'xiaomi', [
    'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
  ]),
  oppo('OPPO', 'oppo', _colorOsAutostart),
  realme('realme', 'realme', _colorOsAutostart),
  vivo('vivo', 'vivo', [
    'com.vivo.permissionmanager/.activity.BgStartUpManagerActivity',
    'com.iqoo.secure/.ui.phoneoptimize.BgStartUpManager',
    'com.iqoo.secure/.ui.phoneoptimize.AddWhiteListActivity',
  ]),
  // Tecno, Infinix and itel are all Transsion phones sharing Phone Master;
  // dontkillmyapp.com only has a Tecno page, which covers all three.
  tecno('Tecno', 'tecno', _phoneMasterAutostart),
  infinix('Infinix', 'tecno', _phoneMasterAutostart),
  itel('itel', 'tecno', _phoneMasterAutostart),
  // Samsung has no autostart switch; its killer is the Sleeping apps list in
  // Device care's battery screen, so that's what the shortcut opens.
  samsung('Samsung', 'samsung', [
    'com.samsung.android.lool/com.samsung.android.sm.battery.ui.BatteryActivity',
    'com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity',
  ]);

  const OemBrand(this.label, this.slug, this.autostart);

  final String label;
  final String slug;
  final List<String> autostart;

  Uri get guideUrl => Uri.https('dontkillmyapp.com', '/$slug');
}

// OPPO and realme share ColorOS's security app.
const _colorOsAutostart = [
  'com.coloros.safecenter/.permission.startup.StartupAppListActivity',
  'com.coloros.safecenter/.startupapp.StartupAppListActivity',
  'com.oppo.safe/.permission.startup.StartupAppListActivity',
];

const _phoneMasterAutostart = [
  'com.transsion.phonemaster/com.cyin.himgr.autostart.AutoStartActivity',
];

/// The brand for Android's `Build.MANUFACTURER`, or null for any other maker.
/// Redmi and POCO are Xiaomi; iQOO is vivo. Transsion phones report either
/// the bare brand or the company name ("INFINIX MOBILITY LIMITED"), so those
/// match on the first word.
OemBrand? oemBrandFor(String? manufacturer) {
  final m = manufacturer?.trim().toLowerCase() ?? '';
  return switch (m.split(' ').first) {
    'xiaomi' || 'redmi' || 'poco' => OemBrand.xiaomi,
    'oppo' => OemBrand.oppo,
    'realme' => OemBrand.realme,
    'vivo' || 'iqoo' => OemBrand.vivo,
    'tecno' => OemBrand.tecno,
    'infinix' => OemBrand.infinix,
    'itel' => OemBrand.itel,
    'samsung' => OemBrand.samsung,
    _ => null,
  };
}

const _channel = MethodChannel('throttleiq/oem');

/// This phone's brand when it is one of [OemBrand]; null elsewhere and on iOS.
Future<OemBrand?> currentOemBrand() async {
  if (!Platform.isAndroid) return null;
  try {
    return oemBrandFor(await _channel.invokeMethod<String>('manufacturer'));
  } catch (e) {
    debugPrint('[OemGuide] manufacturer unavailable: $e');
    return null;
  }
}

/// Set once the guide has been offered, whatever the answer.
const kOemGuideOfferedPref = 'oem_guide_offered';

/// Offers the guide once, after the rider's first finished ride, on a phone
/// from one of the [OemBrand] makers.
Future<void> maybeOfferOemGuide(
  BuildContext context, {
  required bool hasFinishedRide,
  @visibleForTesting Future<OemBrand?> Function() brandLookup = currentOemBrand,
}) async {
  if (!hasFinishedRide) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kOemGuideOfferedPref) ?? false) return;
  final brand = await brandLookup();
  if (brand == null || !context.mounted) return;
  await prefs.setBool(kOemGuideOfferedPref, true);
  if (!context.mounted) return;
  final l10n = context.l10n;
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.oemGuideOfferTitle(brand.label)),
      content: Text(l10n.oemGuideOfferBody(brand.label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.oemGuideShowMe),
        ),
      ],
    ),
  );
  if (open != true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => OemGuideScreen(brand: brand)),
  );
}

/// The three settings that keep a ride recording on [brand]'s phones, each
/// with a shortcut where the phone has one.
class OemGuideScreen extends StatelessWidget {
  const OemGuideScreen({super.key, required this.brand});

  final OemBrand brand;

  Future<void> _openAutostart() async {
    var opened = false;
    try {
      opened =
          await _channel.invokeMethod<bool>('openFirst', brand.autostart) ??
              false;
    } catch (e) {
      debugPrint('[OemGuide] autostart screen failed: $e');
    }
    // App info carries the autostart switch on some of these builds.
    if (!opened) await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget step(int n, String text, {Widget? action}) => Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 14, child: Text('$n')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 15)),
                    if (action != null) action,
                  ],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(l10n.oemGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        children: [
          Text(l10n.oemGuideIntro(brand.label),
              style: TextStyle(
                  fontSize: 15, color: context.palette.textSecondary)),
          const SizedBox(height: AppDimensions.paddingLg),
          if (brand == OemBrand.samsung)
            step(1, l10n.oemGuideStepSleepingApps,
                action: TextButton(
                  onPressed: _openAutostart,
                  child: Text(l10n.oemGuideOpenBatterySettings),
                ))
          else
            step(1, l10n.oemGuideStepAutostart,
                action: TextButton(
                  onPressed: _openAutostart,
                  child: Text(l10n.oemGuideOpenAutostart),
                )),
          step(2, l10n.oemGuideStepBattery,
              action: TextButton(
                onPressed: Geolocator.openAppSettings,
                child: Text(l10n.openAppSettings),
              )),
          step(3, l10n.oemGuideStepLock),
          TextButton.icon(
            onPressed: () =>
                launchUrl(brand.guideUrl, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.oemGuideMoreHelp(brand.label)),
          ),
        ],
      ),
    );
  }
}
