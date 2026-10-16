import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../poi_directory/domain/place_directions.dart';
import '../../../profile/presentation/providers/emergency_contacts_provider.dart';
import '../../domain/sos_message.dart';

/// The active ride's SOS: text the rider's emergency contacts their live
/// location, or call 999. Both hand off to the phone's own apps and the
/// rider presses Send/Call, so nothing goes out silently and it works on
/// plain cellular SMS with no data.
class SosSheet extends StatefulWidget {
  /// Emergency contact numbers; null while they are still loading.
  final List<String>? phones;

  /// Turns live sharing on and returns the viewer URL, or null if it could
  /// not be had (offline, ride not active). Must not throw.
  final Future<String?> Function() liveUrl;

  /// Map pin for the last GPS fix, or null without one.
  final String? mapUrl;

  const SosSheet({
    super.key,
    required this.phones,
    required this.liveUrl,
    required this.mapUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<String?> Function() liveUrl,
    required String? mapUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final contacts = ref.watch(emergencyContactsNotifierProvider);
        return SosSheet(
          phones: contacts.isLoading
              ? null
              : [for (final c in contacts.valueOrNull ?? const []) c.phone],
          liveUrl: liveUrl,
          mapUrl: mapUrl,
        );
      }),
    );
  }

  @override
  State<SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<SosSheet> {
  bool _busy = false;

  Future<void> _launch(Uri? uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.sosCouldNotOpen;
    final ok = uri != null && await launchUrl(uri);
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  Future<void> _textContacts() async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    final live = await widget.liveUrl();
    final body = [
      l10n.sosMessageIntro,
      if (live != null) l10n.sosMessageLive(live),
      if (widget.mapUrl != null) l10n.sosMessageMap(widget.mapUrl!),
    ].join('\n');
    if (!mounted) return;
    setState(() => _busy = false);
    await _launch(sosSmsUri(widget.phones ?? const [], body,
        iOS: defaultTargetPlatform == TargetPlatform.iOS));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phones = widget.phones;
    final danger = context.palette.danger;
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(context.shape.radiusXl)),
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      // ListTile ink paints on the nearest Material, above this decoration.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sosSheetTitle,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary)),
            const SizedBox(height: 12),
            if (phones == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sosSmsUri(phones, '', iOS: false) == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.sosNoContacts,
                    key: const Key('sosNoContacts'),
                    style: TextStyle(
                        fontSize: 13, color: context.palette.textSecondary)),
              )
            else
              ListTile(
                key: const Key('sosTextContacts'),
                contentPadding: EdgeInsets.zero,
                leading: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.sms_outlined, color: danger),
                title: Text(l10n.sosTextContacts,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(l10n.sosTextContactsBody),
                onTap: _busy ? null : _textContacts,
              ),
            ListTile(
              key: const Key('sosCall999'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.call, color: danger),
              title: Text(l10n.sosCallEmergency,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(l10n.sosCallEmergencyBody),
              onTap: () => _launch(telUri(kBangladeshEmergencyNumber)),
            ),
          ],
        ),
      ),
    );
  }
}
