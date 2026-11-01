import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cloud/export_service.dart';
import '../../core/i18n/l10n_context.dart';
import '../../core/services/app_update_gate.dart';
import '../../core/theme/app_theme_context.dart';
import 'editorial.dart';

/// Shown instead of the whole app when this build is older than
/// `config/app.minBuild` (see app_update_gate.dart). No way past it but the
/// update link (Google Play on Android, the install page on iOS), and a way
/// to take the rider's rides along.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, this.exportRides});

  /// Writes the files to share; defaults to
  /// [ExportService.exportAllRidesToGPX]. Tests pass their own.
  final Future<List<File>> Function()? exportRides;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_rounded,
                    size: 56, color: context.palette.primary),
                const SizedBox(height: 16),
                Text(
                  context.l10n.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: display(context, 24),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(updateUrlFor(defaultTargetPlatform)),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(defaultTargetPlatform == TargetPlatform.android
                      ? context.l10n.updateRequiredPlayAction
                      : context.l10n.updateRequiredAction),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('update-required-export-rides'),
                  onPressed: () => _exportRides(context),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(context.l10n.updateRequiredExportRides),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportRides(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files =
          await (exportRides ?? ExportService().exportAllRidesToGPX)();
      if (files.isEmpty) {
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.updateRequiredNoRidesToExport)));
        return;
      }
      await Share.shareXFiles([for (final f in files) XFile(f.path)],
          subject: l10n.rideExportShareSubject);
    } catch (e) {
      debugPrint('[UpdateRequired] export failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailedMessage)));
    }
  }
}
