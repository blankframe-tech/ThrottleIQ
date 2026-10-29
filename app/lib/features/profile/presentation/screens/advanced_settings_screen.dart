import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_modules.dart';
import '../../../../core/services/crash_detection_settings.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../indriyo/data/mjpeg_stream_service.dart';
import '../../../indriyo/presentation/providers/indriyo_provider.dart';
import '../../../poi_directory/presentation/providers/places_provider.dart';
import '../../../ride/presentation/providers/auto_tracking_provider.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../widgets/settings_segmented_option.dart';

/// Settings → Advanced: things most riders never need to touch. Which parts
/// of the app are on, the offline places cache, the crash-research opt-in,
/// and pairing the Indriyo rear camera.
class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(context.l10n.advancedSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AppModulesSection(),
          SizedBox(height: 24),
          _IndriyoSection(),
          SizedBox(height: 24),
          _PlacesCacheTile(),
          SizedBox(height: 10),
          _CrashResearchToggleTile(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Indriyo pairing: on/off, the camera's stream address, a connection test,
/// and the demo simulation. Saved by [IndriyoSettingsNotifier].
class _IndriyoSection extends ConsumerStatefulWidget {
  const _IndriyoSection();

  @override
  ConsumerState<_IndriyoSection> createState() => _IndriyoSectionState();
}

class _IndriyoSectionState extends ConsumerState<_IndriyoSection> {
  late final TextEditingController _url;
  bool _testing = false;
  bool? _reachable;
  bool _invalidUrl = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(
        text: ref.read(indriyoSettingsProvider).streamUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Saves the address if it is a valid http(s) URL; returns it, or null.
  String? _saveUrl() {
    final text = _url.text.trim();
    final uri = Uri.tryParse(text);
    final ok = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    setState(() => _invalidUrl = !ok);
    if (!ok) return null;
    unawaited(ref.read(indriyoSettingsProvider.notifier).setStreamUrl(text));
    return text;
  }

  Future<void> _test() async {
    final url = _saveUrl();
    if (url == null) return;
    setState(() {
      _testing = true;
      _reachable = null;
    });
    final ok = await MjpegStreamService.probe(url);
    if (mounted) {
      setState(() {
        _testing = false;
        _reachable = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(indriyoSettingsProvider);
    final notifier = ref.read(indriyoSettingsProvider.notifier);
    // The saved address loads after the first frame; show it once it lands.
    ref.listen(indriyoSettingsProvider.select((s) => s.streamUrl), (_, next) {
      if (_url.text != next) _url.text = next;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.indriyoSection,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary)),
        const SizedBox(height: 4),
        Text(l10n.indriyoDescription,
            style:
                TextStyle(fontSize: 12, color: context.palette.textTertiary)),
        const SizedBox(height: 12),
        _ModuleSwitchTile(
          key: const Key('indriyo_enable_switch'),
          icon: Icons.radar_rounded,
          title: l10n.indriyoEnableTitle,
          subtitle: l10n.indriyoEnableSubtitle,
          value: settings.enabled,
          onChanged: notifier.setEnabled,
        ),
        if (settings.enabled) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.indriyoPairingSteps,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.palette.textSecondary)),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('indriyo_stream_url'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onSubmitted: (_) => _saveUrl(),
                  decoration: InputDecoration(
                    labelText: l10n.indriyoStreamUrlLabel,
                    errorText: _invalidUrl ? l10n.indriyoInvalidUrl : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      key: const Key('indriyo_test_connection'),
                      onPressed: _testing ? null : _test,
                      icon: const Icon(Icons.wifi_find, size: 18),
                      label: Text(_testing
                          ? l10n.indriyoTesting
                          : l10n.indriyoTestConnection),
                    ),
                  ],
                ),
                if (_reachable != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          _reachable!
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 18,
                          color: _reachable!
                              ? context.palette.success
                              : context.palette.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            _reachable!
                                ? l10n.indriyoConnected
                                : l10n.indriyoNotConnected,
                            style: TextStyle(
                                fontSize: 13,
                                color: context.palette.textPrimary)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ModuleSwitchTile(
            icon: Icons.science_outlined,
            title: l10n.indriyoSimulationTitle,
            subtitle: l10n.indriyoSimulationSubtitle,
            value: settings.isSimulationMode,
            onChanged: notifier.setSimulationMode,
          ),
        ],
      ],
    );
  }
}

/// Places (fuel pumps, garages, ...) kept on the device from rides and the
/// Places tab, with a button to drop them all.
class _PlacesCacheTile extends ConsumerWidget {
  const _PlacesCacheTile();

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final cleared = context.l10n.placesCacheCleared;
    final failed = context.l10n.placesCacheClearFailed;
    try {
      await ref.read(placesCacheProvider).clear();
      ref.invalidate(nearbyPlacesProvider);
      messenger.showSnackBar(SnackBar(content: Text(cleared)));
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'clear places cache');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_pin_outlined,
              color: context.palette.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.placesCacheTitle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 2),
                Text(l10n.placesCacheSubtitle,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
          ),
          TextButton(
            key: const Key('settings_clear_places_cache'),
            onPressed: () => _clear(context, ref),
            child: Text(l10n.placesCacheClear),
          ),
        ],
      ),
    );
  }
}

/// Settings → Advanced → Your ThrottleIQ: which parts of the app the rider wants
/// ([AppModules]). Turning a part off asks first and says what it costs —
/// gently, since the rider is choosing a smaller app on purpose. Turning one
/// back on needs no confirmation.
class _AppModulesSection extends ConsumerWidget {
  const _AppModulesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final modules = ref.watch(appModulesProvider);

    Widget community(CommunityMode mode, String label, String description) =>
        Expanded(
          child: SettingsSegmentedOption(
            label: label,
            description: description,
            selected: modules.community == mode,
            onTap: () =>
                _apply(context, ref, modules.copyWith(community: mode)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.yourThrottleIqSection,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary)),
        const SizedBox(height: 4),
        Text(l10n.yourThrottleIqDescription,
            style:
                TextStyle(fontSize: 12, color: context.palette.textTertiary)),
        const SizedBox(height: 12),
        Text(l10n.communityFieldLabel,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.palette.textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(context.shape.radiusMd),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              community(CommunityMode.full, l10n.communityFullLabel,
                  l10n.communityFullDescription),
              const SizedBox(width: 4),
              community(CommunityMode.forumsOnly, l10n.communityForumsLabel,
                  l10n.communityForumsDescription),
              const SizedBox(width: 4),
              community(CommunityMode.off, l10n.communityOffLabel,
                  l10n.communityOffDescription),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ModuleSwitchTile(
          icon: Icons.place_outlined,
          title: l10n.placesModuleTitle,
          subtitle: l10n.placesModuleSubtitle,
          value: modules.places,
          onChanged: (v) => _apply(context, ref, modules.copyWith(places: v)),
        ),
        const SizedBox(height: 10),
        _ModuleSwitchTile(
          icon: Icons.my_location,
          title: l10n.rideTrackingModuleTitle,
          subtitle: l10n.rideTrackingModuleSubtitle,
          value: modules.rideTracking,
          onChanged: (v) =>
              _apply(context, ref, modules.copyWith(rideTracking: v)),
        ),
      ],
    );
  }

  /// Confirms anything being turned off, then saves. Turning ride tracking
  /// off also switches auto-tracking off, so nothing reads location in the
  /// background; it is refused mid-ride rather than cutting a recording short.
  Future<void> _apply(
      BuildContext context, WidgetRef ref, AppModules next) async {
    final l10n = context.l10n;
    final current = ref.read(appModulesProvider);
    if (next.community == current.community &&
        next.places == current.places &&
        next.rideTracking == current.rideTracking) {
      return;
    }

    final stopsTracking = current.rideTracking && !next.rideTracking;
    if (stopsTracking &&
        ref.read(rideRecordingProvider).status != RecordingStatus.idle &&
        ref.read(rideRecordingProvider).status != RecordingStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rideTrackingOffDuringRide)));
      return;
    }

    final (String, String)? warning = stopsTracking
        ? (l10n.rideTrackingOffWarningTitle, l10n.rideTrackingOffWarningBody)
        : current.places && !next.places
            ? (l10n.placesOffWarningTitle, l10n.placesOffWarningBody)
            : current.forums && !next.forums
                ? (l10n.communityOffWarningTitle, l10n.communityOffWarningBody)
                : current.social && !next.social
                    ? (
                        l10n.communityForumsOnlyWarningTitle,
                        l10n.communityForumsOnlyWarningBody
                      )
                    : null;
    if (warning != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: dialogCtx.palette.surface,
          title: Text(warning.$1,
              style: TextStyle(
                  color: dialogCtx.palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          content: Text(warning.$2,
              style: TextStyle(
                  color: dialogCtx.palette.textSecondary,
                  fontSize: 14,
                  height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: dialogCtx.palette.textSecondary),
              child: Text(dialogCtx.l10n.moduleTurnOffAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(dialogCtx.l10n.moduleKeepOnAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    if (stopsTracking) {
      await ref.read(autoTrackingEnabledProvider.notifier).disable();
    }
    await ref.read(appModulesProvider.notifier).set(next);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.modulesUpdatedSnack)));
    }
  }
}

class _ModuleSwitchTile extends StatelessWidget {
  const _ModuleSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.palette.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Settings → Advanced: the opt-in for sharing answered impacts with
/// the crash-detection research set (`crashEvents`). Off by default;
/// persisted by [CrashResearchConsent].
class _CrashResearchToggleTile extends ConsumerStatefulWidget {
  const _CrashResearchToggleTile();

  @override
  ConsumerState<_CrashResearchToggleTile> createState() =>
      _CrashResearchToggleTileState();
}

class _CrashResearchToggleTileState
    extends ConsumerState<_CrashResearchToggleTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    CrashResearchConsent.isEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined,
              color: context.palette.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.crashResearchTitle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 2),
                Text(context.l10n.crashResearchDesc,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
          ),
          Switch(
            key: const Key('crash_research_switch'),
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              unawaited(CrashResearchConsent.setEnabled(v,
                  uid: ref.read(currentUserProvider)?.uid));
            },
          ),
        ],
      ),
    );
  }
}
