import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ride_recording_provider.dart';

typedef ParkingPin = ({LatLng point, DateTime at});

/// "My bike is parked here" — device-only, and only meaningful while the ride
/// it was dropped on is paused.
///
/// The listener fires immediately, not just on changes: this provider is
/// lazy, so a ride can end (or a restored ride be discarded) without it ever
/// being built, and the pin left in prefs would otherwise resurface on the
/// next paused ride pointing at an old spot.
final parkingPinProvider =
    StateNotifierProvider<ParkingPinNotifier, ParkingPin?>((ref) {
  final notifier = ParkingPinNotifier(
    rideStart: () => ref.read(rideRecordingProvider).ride?.startTime,
  );
  ref.listen<RecordingStatus>(
    rideRecordingProvider.select((s) => s.status),
    (previous, next) {
      if (next != RecordingStatus.paused) notifier.clear();
    },
    fireImmediately: true,
  );
  return notifier;
});

class ParkingPinNotifier extends StateNotifier<ParkingPin?> {
  static const String prefsKey = 'parking_pin';

  /// Start of the ride in progress; a stored pin older than this belongs to
  /// an earlier ride and is dropped on load.
  final DateTime? Function() _rideStart;

  /// Bumped by every [drop]/[clear], so a slow initial load can't overwrite
  /// a newer decision with what was on disk.
  int _generation = 0;

  ParkingPinNotifier({
    SharedPreferences? prefs,
    DateTime? Function()? rideStart,
  })  : _rideStart = rideStart ?? (() => null),
        super(null) {
    if (prefs != null) {
      _loadFrom(prefs);
    } else {
      _load();
    }
  }

  void _loadFrom(SharedPreferences prefs) {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return;
    final pin = parse(raw);
    final start = _rideStart();
    if (pin == null || (start != null && pin.at.isBefore(start))) {
      prefs.remove(prefsKey);
      return;
    }
    state = pin;
  }

  Future<void> _load() async {
    final generation = _generation;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || generation != _generation) return;
    _loadFrom(prefs);
  }

  static ParkingPin? parse(String raw) {
    final parts = raw.split(',');
    if (parts.length != 3) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    final ms = int.tryParse(parts[2]);
    if (lat == null || lng == null || ms == null) return null;
    return (
      point: LatLng(lat, lng),
      at: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  Future<void> drop(LatLng point) async {
    _generation++;
    final now = DateTime.now();
    state = (point: point, at: now);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      '${point.latitude},${point.longitude},${now.millisecondsSinceEpoch}',
    );
  }

  Future<void> clear() async {
    _generation++;
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}
