import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../shared/widgets/bug_report_sheet.dart';
import '../providers/places_provider.dart';

/// A centered icon + title + body + actions block, the shape every Places
/// hub status (error, empty, no matches) shares.
class PlacesStatusPanel extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? body;
  final List<Widget> actions;

  const PlacesStatusPanel({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: iconColor ?? context.palette.textTertiary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final action in actions)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// What went wrong loading nearby places, with the button that fixes it:
/// GPS off → location settings; permission denied → ask again; permanently
/// denied → app settings; offline → retry, or fall back to the Saved tab
/// (which works with no signal); anything else → retry and report.
class PlacesErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onOpenSaved;

  const PlacesErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onOpenSaved,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final savedButton = OutlinedButton.icon(
      onPressed: onOpenSaved,
      icon: const Icon(Icons.bookmark_outline, size: 18),
      label: Text(l10n.placesOpenSaved),
    );

    final error = this.error;
    if (error is PlaceLocationException) {
      return switch (error.problem) {
        PlaceLocationProblem.serviceDisabled => PlacesStatusPanel(
            icon: Icons.location_off_outlined,
            title: l10n.placesGpsOffTitle,
            body: l10n.errLocationOff,
            actions: [
              ElevatedButton.icon(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  onRetry();
                },
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(l10n.turnOnLocation),
              ),
              savedButton,
            ],
          ),
        PlaceLocationProblem.permissionDenied => PlacesStatusPanel(
            icon: Icons.location_disabled_outlined,
            title: l10n.placesLocationDeniedTitle,
            body: l10n.errLocationPermission,
            actions: [
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(l10n.placesAllowLocation),
              ),
              savedButton,
            ],
          ),
        PlaceLocationProblem.permissionDeniedForever => PlacesStatusPanel(
            icon: Icons.location_disabled_outlined,
            title: l10n.placesLocationDeniedTitle,
            body: l10n.errLocationPermission,
            actions: [
              ElevatedButton.icon(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  onRetry();
                },
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(l10n.openSettings),
              ),
              savedButton,
            ],
          ),
      };
    }

    final message = mapFirestoreError(error, l10n);
    if (message == l10n.errOffline) {
      return PlacesStatusPanel(
        icon: Icons.cloud_off_outlined,
        title: l10n.placesOfflineTitle,
        body: l10n.placesOfflineBody,
        actions: [
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.tryAgain),
          ),
          savedButton,
        ],
      );
    }

    return PlacesStatusPanel(
      icon: Icons.error_outline_rounded,
      title: message,
      actions: [
        OutlinedButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        TextButton.icon(
          onPressed: () => BugReportSheet.show(context),
          icon: const Icon(Icons.bug_report_outlined, size: 16),
          label: Text(l10n.reportProblem),
          style: TextButton.styleFrom(foregroundColor: context.palette.textTertiary),
        ),
      ],
    );
  }
}
