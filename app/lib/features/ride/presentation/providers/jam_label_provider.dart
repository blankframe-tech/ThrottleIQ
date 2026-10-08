import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/beta_testers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/jam_label_repository.dart';
import '../../domain/entities/jam_label_entity.dart';
import 'ride_recording_provider.dart';

/// Whether the signed-in rider gets the beta jam-labelling buttons.
final canLabelJamsProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.email == 'the.abraar.rar@gmail.com') return true;
  final profile = ref.watch(myProfileProvider).valueOrNull;
  return BetaTesters.canLabelJams(profile?.username);
});

final jamLabelRepositoryProvider =
    Provider<JamLabelRepository>((ref) => JamLabelRepository());

/// The rider's currently open jam label, or null when they haven't said
/// they're in a jam.
///
/// Not autoDispose: it has to outlive the active ride screen long enough to
/// close an open label when the ride ends and the screen pops.
final jamLabelProvider =
    StateNotifierProvider<JamLabelNotifier, JamLabel?>((ref) {
  final repo = ref.watch(jamLabelRepositoryProvider);
  final notifier = JamLabelNotifier(
    save: (label) {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) repo.save(uid, label);
    },
  );
  ref.listen<RideRecordingState>(
    rideRecordingProvider,
    (prev, next) {
      if (prev != null) notifier.onRecordingChanged(prev, next);
    },
  );
  return notifier;
});

/// Beta: rider-labelled jam windows on an active ride (see JamLabel).
class JamLabelNotifier extends StateNotifier<JamLabel?> {
  JamLabelNotifier({
    required void Function(JamLabel) save,
    DateTime Function()? now,
    String Function()? newId,
  })  : _save = save,
        _now = now ?? DateTime.now,
        _newId = newId ?? (() => const Uuid().v4()),
        super(null);

  final void Function(JamLabel) _save;
  final DateTime Function() _now;
  final String Function() _newId;

  JamLabelMark _mark(RideRecordingState s) => JamLabelMark(
        at: _now(),
        elapsedSeconds: s.elapsed.inSeconds,
        movingSeconds: s.movingSeconds,
        distanceM: s.distanceM,
        speedMs: s.currentSpeedMs,
        lat: s.currentPosition?.latitude,
        lng: s.currentPosition?.longitude,
      );

  /// "I'm in a jam". Only on an actively recording ride, and only one open
  /// label at a time.
  void startJam(RideRecordingState s) {
    final ride = s.ride;
    if (state != null || ride == null || s.status != RecordingStatus.active) {
      return;
    }
    final label = JamLabel(id: _newId(), rideId: ride.id, start: _mark(s));
    state = label;
    // Saved open too, so an app kill mid-jam still leaves the start on record.
    _save(label);
  }

  /// "Jam released".
  void releaseJam(RideRecordingState s) =>
      _close(_mark(s), JamLabelEndReason.released);

  /// Closes an open label when the ride stops being actively recorded.
  /// Snapshots [prev] when it was still active — after a stop the recorder's
  /// counters may already be reset.
  void onRecordingChanged(RideRecordingState prev, RideRecordingState next) {
    if (state == null) return;
    final rideChanged = next.ride?.id != state!.rideId;
    if (next.status == RecordingStatus.active && !rideChanged) return;
    _close(
      _mark(prev.status == RecordingStatus.active ? prev : next),
      next.status == RecordingStatus.paused && !rideChanged
          ? JamLabelEndReason.paused
          : JamLabelEndReason.rideEnded,
    );
  }

  void _close(JamLabelMark mark, JamLabelEndReason reason) {
    final open = state;
    if (open == null) return;
    final closed = open.close(mark, reason);
    state = null;
    _save(closed);
  }
}
