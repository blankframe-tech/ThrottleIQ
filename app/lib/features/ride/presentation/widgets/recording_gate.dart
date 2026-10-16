/// The checks and the rider-facing wording that every "start a ride" control
/// has to go through, wherever it lives, plus the background-location
/// disclosure that turning auto-tracking on goes through.
///
/// This used to be three private helpers inside `record_screen.dart`, which
/// was fine while the Record button was the only way to start recording.
/// Following a saved route now starts one too (issues §78.21).
library;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/ride_recording_provider.dart';

/// Set once the rider has accepted the background-location disclosure.
const kBackgroundDisclosureAcceptedPref =
    'background_location_disclosure_accepted';

/// The in-app disclosure Play's background-location policy requires before
/// the "Allow all the time" request. Only turning auto-tracking on makes that
/// request; a manual ride needs while-in-use only (B4), so ride starts no
/// longer come through here.
///
/// Shown until the rider accepts it once, then never again. Returns false
/// if they back out ("Not now"), and the request is not made; the next tap
/// on the auto-tracking switch shows it again, since that is the only way to
/// grant it.
Future<bool> ensureBackgroundLocationDisclosure(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kBackgroundDisclosureAcceptedPref) ?? false) return true;
  if (await Geolocator.checkPermission() == LocationPermission.always) {
    return true;
  }
  if (!context.mounted) return false;
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.backgroundLocation),
      content: Text(
        context.l10n.backgroundLocationRationale,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(context.l10n.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(context.l10n.continueLabel),
        ),
      ],
    ),
  );
  if (proceed != true) return false;
  await prefs.setBool(kBackgroundDisclosureAcceptedPref, true);
  return true;
}

/// Puts the blocked-recording reason (GPS off / no permission) in front of
/// the rider immediately, as a SnackBar with a one-tap fix — the persistent
/// card above the start control says the same thing, but it can sit below
/// the fold behind the hero/stat-strip/friends cards, so a rider who just
/// slid the bar and got nothing back would otherwise have to scroll up to
/// find out why.
void showRecordingBlockedSnackBar(
    BuildContext context, RideRecordingState state) {
  if (state.error == null) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(recordingErrorText(context.l10n, state)),
    duration: const Duration(seconds: 6),
    action: switch (state.blockKind) {
      RecordingBlockKind.locationServicesOff => SnackBarAction(
          label: context.l10n.turnOnCaps,
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      RecordingBlockKind.permissionDenied => SnackBarAction(
          label: context.l10n.settingsCaps,
          onPressed: () => Geolocator.openAppSettings(),
        ),
      RecordingBlockKind.none => null,
    },
  ));
}

/// The rider-facing text for [RideRecordingState.error].
///
/// The notifier keeps `error` in English (it doubles as a diagnostic), so the
/// screen localizes it from what it already knows: [RideRecordingState.blockKind]
/// for the two location problems, [kNoBikeRecordingError] for the missing
/// bike, and [kStartFailedRecordingError] for a start that threw. Anything else is shown as written.
String recordingErrorText(AppLocalizations l10n, RideRecordingState state) =>
    switch (state.blockKind) {
      RecordingBlockKind.locationServicesOff => l10n.recordingLocationOff,
      RecordingBlockKind.permissionDenied => l10n.recordingPermissionDenied,
      RecordingBlockKind.none => switch (state.error) {
          kNoBikeRecordingError => l10n.addBikeBeforeRecording,
          kStartFailedRecordingError => l10n.recordingStartFailed,
          _ => state.error!,
        },
    };
