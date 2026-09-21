/// The checks and the rider-facing wording that every "start a ride" control
/// has to go through, wherever it lives.
///
/// This used to be three private helpers inside `record_screen.dart`, which
/// was fine while the Record button was the only way to start recording.
/// Following a saved route now starts one too (issues §78.21), and the Play
/// background-location disclosure below is not optional for *that* entry
/// point either — a second copy of it would be a policy violation waiting for
/// someone to forget it.
library;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/ride_recording_provider.dart';

/// Shown once, right before the OS location prompts, whenever the rider
/// hasn't already granted "Allow all the time" — this is the in-app
/// disclosure Play's background-location policy requires be distinct from
/// the system dialog. Returns false (and shows nothing further) if the rider
/// backs out here rather than proceeding to the OS prompts.
Future<bool> ensureLocationDisclosure(BuildContext context) async {
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
  return proceed ?? false;
}

/// Puts the blocked-recording reason (GPS off / no permission) in front of
/// the rider immediately, as a SnackBar with a one-tap fix — the persistent
/// card above the start control says the same thing, but it can sit below
/// the fold behind the hero/stat-strip/friends cards, so a rider who just
/// slid the bar and got nothing back would otherwise have to scroll up to
/// find out why.
void showRecordingBlockedSnackBar(BuildContext context, RideRecordingState state) {
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
/// for the two location problems, and [kNoBikeRecordingError] for the missing
/// bike. Anything else is shown as written.
String recordingErrorText(AppLocalizations l10n, RideRecordingState state) =>
    switch (state.blockKind) {
      RecordingBlockKind.locationServicesOff => l10n.recordingLocationOff,
      RecordingBlockKind.permissionDenied => l10n.recordingPermissionDenied,
      RecordingBlockKind.none => state.error == kNoBikeRecordingError
          ? l10n.addBikeBeforeRecording
          : state.error!,
    };
