import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/place_directions.dart';

/// The one-tap hand-offs every place surface shares — the detail screen,
/// the hub's list cards, the map carousel and the Saved tab — so "Directions"
/// asks the same record-this-ride question and fails the same way wherever
/// the rider taps it.
abstract final class PlaceLaunchActions {
  /// SharedPreferences key for a remembered "Record this ride?" answer —
  /// `'record'` or `'directions'`; absent means ask every time.
  static const directionsChoiceKey = 'place_directions_record_choice';

  /// Whether to record a ride alongside the directions. Asked rather than
  /// assumed (grill §3.2.2): the button used to start a recording
  /// silently, which a rider who only wanted the route never agreed to.
  /// Returns null when the rider backed out of the sheet, in which case
  /// nothing launches at all.
  static Future<bool?> _shouldRecord(BuildContext context, WidgetRef ref) async {
    // A ride already running is just carried on — nothing to ask.
    final status = ref.read(rideRecordingProvider).status;
    if (status != RecordingStatus.idle && status != RecordingStatus.completed) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getString(directionsChoiceKey);
    if (remembered == 'record') return true;
    if (remembered == 'directions') return false;
    if (!context.mounted) return null;

    final answer = await showModalBottomSheet<(bool, bool)>(
      context: context,
      backgroundColor: context.palette.surface,
      builder: (_) => const _RecordChoiceSheet(),
    );
    if (answer == null) return null;
    final (record, dontAskAgain) = answer;
    if (dontAskAgain) {
      await prefs.setString(directionsChoiceKey, record ? 'record' : 'directions');
    }
    return record;
  }

  /// Opens the rider's maps app at driving directions to [place].
  ///
  /// `LaunchMode.externalApplication` matters: the default mode can open the
  /// link in an in-app webview on Android, which produces a *map of the route*
  /// with no live guidance — the opposite of what "Directions" promises. This
  /// forces the real Google Maps app (or the browser if it isn't installed).
  ///
  /// On iOS, if that fails outright we retry with Apple Maps, which is always
  /// present. A failure on either is reported rather than swallowed: a button
  /// that silently does nothing is worse than one that says why.
  static Future<void> openDirections(
    BuildContext context,
    WidgetRef ref,
    PlaceEntity place,
  ) async {
    final record = await _shouldRecord(context, ref);
    if (record == null) return;

    // Started *before* handing off to the external app, not after: once
    // launchUrl backgrounds ThrottleIQ, there is no foreground window left for
    // a location-permission prompt to appear in. Silently no-ops (see
    // RideRecordingNotifier.startRide) if there's no bike or permission is
    // missing — a rider who only wanted directions should never see an error
    // from the ride the tap also started.
    if (record) {
      unawaited(ref.read(rideRecordingProvider.notifier).startRide());
    }

    final google = googleMapsDirectionsUri(
      latitude: place.latitude,
      longitude: place.longitude,
    );

    var launched = false;
    try {
      launched = await launchUrl(google, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!launched && Platform.isIOS) {
      final apple = appleMapsDirectionsUri(
        latitude: place.latitude,
        longitude: place.longitude,
        label: place.name,
      );
      try {
        launched =
            await launchUrl(apple, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldntOpenMapsApp)),
      );
    }
  }

  /// Opens the dialler at [uri] (from [telUri]).
  static Future<void> call(BuildContext context, Uri uri) async {
    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldntOpenDialler)),
      );
    }
  }
}

/// "Record this ride in ThrottleIQ?" asked before the Directions hand-off.
/// Pops `(record, dontAskAgain)`.
class _RecordChoiceSheet extends StatefulWidget {
  const _RecordChoiceSheet();

  @override
  State<_RecordChoiceSheet> createState() => _RecordChoiceSheetState();
}

class _RecordChoiceSheetState extends State<_RecordChoiceSheet> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.recordThisRideThrottleiq,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary)),
            const SizedBox(height: 6),
            Text(
              context.l10n.mapsAppGivesDirections,
              style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, (true, _dontAskAgain)),
              icon: const Icon(Icons.fiber_manual_record, size: 18),
              label: Text(context.l10n.recordGo),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, (false, _dontAskAgain)),
              icon: const Icon(Icons.directions, size: 18),
              label: Text(context.l10n.justDirections),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _dontAskAgain,
              onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
              title: Text(context.l10n.dontAskAgain,
                  style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: context.palette.primary,
            ),
          ],
        ),
      ),
    );
  }
}
