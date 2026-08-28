import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/cloudinary_upload_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../domain/entities/group_ride_entity.dart';
import '../../domain/utilities/group_ride_members.dart';
import '../providers/group_ride_providers.dart';
import '../utils/group_ride_colors.dart';

/// How often this device publishes its own position to the group.
///
/// Slower than the ride recorder's own GPS cadence on purpose: the recorder
/// keeps a 3 m-resolution trace for the ride file, whereas the group map only
/// needs "roughly where is everyone", and every publish is a Firestore write
/// billed against all group members' listeners.
const Duration kGroupRideBroadcastInterval = Duration(seconds: 5);

/// Past this age a member's position is shown as stale rather than current.
/// Two broadcast intervals plus slack — long enough that one dropped write
/// doesn't flag a rider who is fine, short enough that a rider who has lost
/// signal for half a minute stops being rendered as live.
const Duration kGroupRideStaleAfter = Duration(seconds: 30);

/// The shared live map for a group ride: every member as a differently
/// coloured marker, updating as they move.
class GroupRideMapScreen extends ConsumerStatefulWidget {
  final String groupRideId;

  /// Set by the `?start=1` query parameter the "Ride with friends" flow
  /// navigates with. The recording is started *here*, after the record screen
  /// has been torn down, rather than in the button — see the comment on
  /// [RideModeSelector]'s navigation for why that race matters.
  final bool autoStartRide;

  const GroupRideMapScreen({
    super.key,
    required this.groupRideId,
    this.autoStartRide = false,
  });

  @override
  ConsumerState<GroupRideMapScreen> createState() => _GroupRideMapScreenState();
}

class _GroupRideMapScreenState extends ConsumerState<GroupRideMapScreen> {
  final MapController _mapCtrl = MapController();

  /// Dhaka — same fallback the solo live map uses, for the moment before any
  /// member has reported a position.
  static const _fallbackCenter = LatLng(23.8103, 90.4125);

  Timer? _broadcastTimer;

  /// Repaints the roster so "last seen 12s ago" keeps counting up even when
  /// nothing is arriving. Without it a group that all lost signal at once
  /// would sit frozen on whatever age it had when the last snapshot landed —
  /// stale data rendered as though it were current, which is exactly the
  /// failure this screen must not have.
  Timer? _staleTicker;

  StreamSubscription<Map<String, Map<String, dynamic>>>? _locationsSub;

  Map<String, Map<String, dynamic>> _locations = const {};
  String? _locationError;
  bool _hasLocationPermission = false;
  bool _leaving = false;

  // -- Voice notes ("Ride with friends" push-to-talk) --------------------

  final AudioRecorder _voiceRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  final CloudinaryUploadService _uploadService = CloudinaryUploadService();

  /// Set once in [initState], synchronously — never null by the time the
  /// voice-notes listener can fire. Notes created at or before this moment
  /// are this ride's history from before the rider opened this screen, and
  /// must never auto-play — only notes strictly after it are "new".
  late final DateTime _screenOpenedAt;

  /// Every note id this device has already queued or explicitly skipped
  /// (its own echo), so a stream re-emission of the same list never
  /// replays or re-queues it.
  final Set<String> _seenVoiceNoteIds = {};
  final List<VoiceNoteEntity> _voiceNoteQueue = [];

  bool _isRecordingVoiceNote = false;
  bool _isSendingVoiceNote = false;
  bool _isPlayingVoiceNote = false;
  bool _voiceNotesMuted = false;
  String? _playingVoiceNoteSender;
  String? _voiceNoteError;
  DateTime? _recordingStartedAt;
  String? _recordingPath;

  /// Only auto-fit the camera to the group once. After that the rider is in
  /// charge of the viewport — yanking it back every time somebody's marker
  /// moved would make the map unusable to pan.
  bool _didInitialFit = false;

  @override
  void initState() {
    super.initState();
    _screenOpenedAt = DateTime.now();
    // Provider mutation and permission prompts both have to wait until after
    // the first frame — neither is legal from initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (widget.autoStartRide) {
      final notifier = ref.read(rideRecordingProvider.notifier);
      // startRide() no-ops unless status is idle, so an already-recording
      // rider who opens a group ride keeps their ride instead of getting a
      // second one.
      await notifier.startRide();
      if (!mounted) return;
    }

    await _ensureLocationPermission();
    if (!mounted) return;

    _locationsSub = ref
        .read(groupRideRepositoryProvider)
        .streamMemberLocations(widget.groupRideId)
        .listen(
      (locations) {
        if (!mounted) return;
        setState(() => _locations = locations);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _locationError = 'Live positions unavailable: $e');
      },
    );

    // Publish once immediately so the rest of the group sees this rider
    // without waiting a full interval, then keep it ticking.
    unawaited(_broadcastPosition());
    _broadcastTimer = Timer.periodic(
      kGroupRideBroadcastInterval,
      (_) => _broadcastPosition(),
    );
    _staleTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _ensureLocationPermission() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      final granted = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      setState(() {
        _hasLocationPermission = granted;
        // Not fatal: without permission this rider can still watch everyone
        // else move, they just don't appear on the group's maps.
        _locationError = granted
            ? null
            : 'Location permission is off — the group can\'t see you. '
                'You can still see them.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasLocationPermission = false;
        _locationError = 'Location unavailable: $e';
      });
    }
  }

  /// Resolves this device's current position, preferring the ride recorder's
  /// own fix when a ride is being recorded (it already has a hot GPS stream —
  /// asking Geolocator for a second independent fix would burn battery for a
  /// position we already have).
  Future<LatLng?> _resolvePosition() async {
    final recorded = ref.read(rideRecordingProvider).currentPosition;
    if (recorded != null) return recorded;
    if (!_hasLocationPermission) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // Timeout / no fix / services turned off mid-ride. Skip this tick; the
      // rider's marker simply goes stale, which is the honest rendering.
      return null;
    }
  }

  Future<void> _broadcastPosition() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final position = await _resolvePosition();
    if (!mounted || position == null) return;

    try {
      await ref.read(groupRideRepositoryProvider).updateMemberLocation(
            groupRideId: widget.groupRideId,
            userId: uid,
            lat: position.latitude,
            lng: position.longitude,
          );
    } catch (_) {
      // A single dropped publish is not worth a visible error — the next tick
      // is five seconds away, and the staleness badge already tells the group
      // this rider has gone quiet.
    }
  }

  Future<void> _leave() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null || _leaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave group ride?'),
        content: const Text(
          'The others stop seeing your position. Your own ride recording '
          'keeps running — end it from the ride screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Leave', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _leaving = true);
    // Stop publishing before the membership write — otherwise an in-flight
    // tick could re-create the location document we're about to delete.
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    try {
      await ref.read(groupRideRepositoryProvider).leaveGroupRide(
            groupRideId: widget.groupRideId,
            userId: uid,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _leaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't leave: $e")));
      return;
    }
    if (!mounted) return;
    context.go('/home/record');
  }

  // ---------------------------------------------------------------------
  // Voice notes
  // ---------------------------------------------------------------------

  /// Runs off [voiceNotesProvider] via `ref.listen` in [build] — see the
  /// call site. Queues any note that is new since this screen opened and
  /// wasn't sent by this device, then kicks the playback queue if it's
  /// idle. A note with no `createdAt` yet (the writer's own pre-round-trip
  /// echo) is left unseen on purpose: it re-emits with a real timestamp
  /// moments later and is picked up then, rather than being misjudged as
  /// "old" or "new" from a null.
  void _onVoiceNotesChanged(List<VoiceNoteEntity> notes) {
    final myUid = ref.read(currentUserProvider)?.uid;

    for (final note in notes) {
      if (_seenVoiceNoteIds.contains(note.id)) continue;
      final createdAt = note.createdAt;
      if (createdAt == null) continue;
      if (!createdAt.isAfter(_screenOpenedAt)) {
        _seenVoiceNoteIds.add(note.id);
        continue;
      }
      _seenVoiceNoteIds.add(note.id);
      if (note.senderId != myUid && !_voiceNotesMuted) {
        _voiceNoteQueue.add(note);
      }
    }

    if (!_isPlayingVoiceNote) unawaited(_playNextVoiceNote());
  }

  Future<void> _playNextVoiceNote() async {
    if (_voiceNoteQueue.isEmpty || _isPlayingVoiceNote || _voiceNotesMuted) {
      return;
    }
    final note = _voiceNoteQueue.removeAt(0);
    if (mounted) {
      setState(() {
        _isPlayingVoiceNote = true;
        _playingVoiceNoteSender = note.senderName;
      });
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.allowBluetoothA2dp,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));
      await session.setActive(true);
      await _voicePlayer.setUrl(note.audioUrl);
      await _voicePlayer.play();
    } catch (_) {
      // A clip that fails to load/play is skipped rather than stalling the
      // rest of the queue — one bad URL must not silence the whole group.
    } finally {
      await _deactivateVoiceAudioSession();
      if (mounted) {
        setState(() {
          _isPlayingVoiceNote = false;
          _playingVoiceNoteSender = null;
        });
      }
      unawaited(_playNextVoiceNote());
    }
  }

  Future<void> _deactivateVoiceAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(
        false,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    } catch (_) {/* best-effort */}
  }

  void _toggleVoiceNotesMuted() {
    setState(() {
      _voiceNotesMuted = !_voiceNotesMuted;
      if (_voiceNotesMuted) _voiceNoteQueue.clear();
    });
  }

  /// Starts recording on press-down. Mirrors this screen's other permission
  /// flows (see [_ensureLocationPermission]): a denial degrades to a
  /// non-fatal banner, never a crash. Goes through `permission_handler`
  /// exclusively — checking `.status` before `.request()` — so `record`'s
  /// own internal permission check sees an already-granted status and never
  /// fires a second native prompt.
  Future<void> _startRecordingVoiceNote() async {
    if (_isRecordingVoiceNote || _isSendingVoiceNote) return;
    if (mounted) setState(() => _voiceNoteError = null);

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _voiceNoteError =
          'Microphone access is off — you can still hear the group.');
      return;
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.allowBluetoothA2dp |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
      ));
      await session.setActive(true);

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _voiceRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecordingVoiceNote = true;
        _recordingStartedAt = DateTime.now();
        _recordingPath = path;
      });
    } catch (e) {
      await _deactivateVoiceAudioSession();
      if (!mounted) return;
      setState(() => _voiceNoteError = "Couldn't start recording: $e");
    }
  }

  /// Stops on release (or on the gesture being cancelled) and sends the
  /// clip. A clip under 800ms is treated as an accidental tap — released
  /// and discarded with no error shown, never uploaded.
  Future<void> _stopRecordingVoiceNoteAndSend() async {
    if (!_isRecordingVoiceNote) return;
    final startedAt = _recordingStartedAt;
    if (mounted) setState(() => _isRecordingVoiceNote = false);

    String? path;
    try {
      path = await _voiceRecorder.stop();
    } catch (_) {
      path = _recordingPath;
    }
    await _deactivateVoiceAudioSession();

    if (path == null || startedAt == null) return;
    final file = File(path);
    final duration = DateTime.now().difference(startedAt);

    if (duration.inMilliseconds < 800) {
      unawaited(file.delete().catchError((_) => file));
      return;
    }

    final user = ref.read(currentUserProvider);
    final uid = user?.uid;
    if (uid == null) {
      unawaited(file.delete().catchError((_) => file));
      return;
    }

    if (mounted) setState(() => _isSendingVoiceNote = true);
    try {
      final url = await _uploadService.uploadAudio(
        file,
        folder: 'voiceNotes/${widget.groupRideId}',
      );
      final senderName = (user?.displayName ?? '').trim().isEmpty
          ? 'Rider'
          : user!.displayName!.trim();
      await ref.read(groupRideRepositoryProvider).sendVoiceNote(
            groupRideId: widget.groupRideId,
            senderId: uid,
            senderName: senderName,
            senderPhotoUrl: user?.photoURL ?? '',
            audioUrl: url,
            durationMs: duration.inMilliseconds,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _voiceNoteError = "Couldn't send voice note: $e");
      }
    } finally {
      unawaited(file.delete().catchError((_) => file));
      if (mounted) setState(() => _isSendingVoiceNote = false);
    }
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    _staleTicker?.cancel();
    _locationsSub?.cancel();
    // Best-effort: if the rider navigates away mid-hold there is nobody left
    // to send the clip to anyway, so the recording is simply abandoned
    // rather than raced to finish.
    if (_isRecordingVoiceNote) {
      unawaited(_voiceRecorder.stop());
    }
    _voiceRecorder.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // View model
  // ---------------------------------------------------------------------

  /// Merges the ride's roster with the live location subcollection into one
  /// ordered list. [roster] arrives already ordered by uid out of
  /// `mergeGroupRideMembers` — not by join time or list order — so a member's
  /// colour index (and therefore their colour) can't shift when somebody else
  /// joins or leaves.
  List<_MemberView> _buildMembers(
      List<GroupRideMember> roster, String? myUid) {
    final ordered = roster;

    return [
      for (var i = 0; i < ordered.length; i++)
        _MemberView(
          member: ordered[i],
          color: colorForMember(ordered[i].userId, i),
          isMe: ordered[i].userId == myUid,
          position: _positionFor(ordered[i]),
          lastUpdate: _lastUpdateFor(ordered[i]),
        ),
    ];
  }

  LatLng? _positionFor(GroupRideMember member) {
    final live = _locations[member.userId];
    final lat = (live?['lat'] as num?)?.toDouble() ?? member.currentLat;
    final lng = (live?['lng'] as num?)?.toDouble() ?? member.currentLng;
    // A member who has never published anything has no coordinates at all.
    // Returning null (rather than defaulting to 0,0) is what keeps them off
    // the map instead of pinned in the Gulf of Guinea.
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  DateTime? _lastUpdateFor(GroupRideMember member) {
    final raw = _locations[member.userId]?['timestamp'];
    // serverTimestamp() reads back null on the writing device until the
    // server round-trip lands, so fall back to whatever the roster carries.
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return member.lastLocationUpdate;
  }

  void _fitToMembers(List<_MemberView> members) {
    final points = [
      for (final m in members)
        if (m.position != null) m.position!,
    ];
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _mapCtrl.move(points.first, 16);
      } else {
        _mapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(64),
            maxZoom: 16,
          ),
        );
      }
    } catch (_) {/* controller not attached to a map yet */}
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(groupRideProvider(widget.groupRideId));
    final rosterAsync = ref.watch(groupRideMembersProvider(widget.groupRideId));
    final myUid = ref.watch(currentUserProvider)?.uid;

    // Side effect only — the roster/map above never renders voice notes
    // directly, this just feeds the playback queue. Riverpod dedupes
    // repeated registration of the same listener across rebuilds, so this
    // is safe to call on every build.
    ref.listen<AsyncValue<List<VoiceNoteEntity>>>(
      voiceNotesProvider(widget.groupRideId),
      (previous, next) {
        final notes = next.valueOrNull;
        if (notes != null) _onVoiceNotesChanged(notes);
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Group ride'),
        actions: [
          TextButton(
            onPressed: _leaving ? null : _leave,
            child: Text('Leave', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
      body: rideAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (ride) {
          if (ride == null) {
            return const _ErrorState(
              message: 'This group ride no longer exists.',
            );
          }

          // The roster lives at `groupRides/{id}/members/{uid}`. A ride created
          // before it moved there carries its members inline on the ride
          // document instead, so both are read and the subcollection wins.
          // A roster stream that hasn't arrived (or that errored) leaves the
          // legacy list showing rather than emptying the map.
          final members = _buildMembers(
            mergeGroupRideMembers(
              legacy: ride.members,
              fromSubcollection: rosterAsync.valueOrNull ?? const [],
            ),
            myUid,
          );

          if (!_didInitialFit && members.any((m) => m.position != null)) {
            _didInitialFit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _fitToMembers(members);
            });
          }

          return Column(
            children: [
              for (final message in [_locationError, _voiceNoteError]
                  .whereType<String>())
                _Banner(message: message),
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    _buildMap(members),
                    if (members.every((m) => m.position == null))
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: _NoPositionsHint(),
                      ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'group-ride-fit',
                        onPressed: () => _fitToMembers(members),
                        backgroundColor: AppColors.surface,
                        child: Icon(Icons.center_focus_strong,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _MemberList(members: members),
              ),
              _buildVoiceNoteBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceNoteBar() {
    final busy = _isSendingVoiceNote;
    final label = _isRecordingVoiceNote
        ? 'Recording — release to send'
        : busy
            ? 'Sending…'
            : _isPlayingVoiceNote
                ? 'Playing ${_playingVoiceNoteSender ?? 'voice note'}…'
                : 'Hold to talk';
    final accent = _isRecordingVoiceNote ? AppColors.danger : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => unawaited(_startRecordingVoiceNote()),
                onTapUp: (_) => unawaited(_stopRecordingVoiceNoteAndSend()),
                onTapCancel: () =>
                    unawaited(_stopRecordingVoiceNoteAndSend()),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: accent),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accent),
                        )
                      else
                        Icon(
                          _isRecordingVoiceNote ? Icons.mic : Icons.mic_none,
                          color: accent,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.w600, color: accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _toggleVoiceNotesMuted,
              tooltip: _voiceNotesMuted
                  ? 'Unmute voice notes'
                  : 'Mute voice notes',
              icon: Icon(
                _voiceNotesMuted ? Icons.volume_off : Icons.volume_up,
                color: _voiceNotesMuted
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(List<_MemberView> members) {
    final me = members.where((m) => m.isMe && m.position != null);

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: me.isNotEmpty
            ? me.first.position!
            : (members.firstWhere(
                  (m) => m.position != null,
                  orElse: () => _MemberView.empty,
                ).position ??
                _fallbackCenter),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bft.throttleiq',
        ),
        MarkerLayer(
          markers: [
            for (final m in members)
              // Members with no position at all are skipped entirely rather
              // than drawn somewhere arbitrary — the roster below says why
              // they're missing.
              if (m.position != null)
                Marker(
                  point: m.position!,
                  width: 44,
                  height: 44,
                  child: _MemberMarker(view: m),
                ),
          ],
        ),
      ],
    );
  }
}

/// One member, merged from the roster and the live location subcollection.
class _MemberView {
  final GroupRideMember member;
  final Color color;
  final bool isMe;
  final LatLng? position;
  final DateTime? lastUpdate;

  const _MemberView({
    required this.member,
    required this.color,
    required this.isMe,
    required this.position,
    required this.lastUpdate,
  });

  static final _MemberView empty = _MemberView(
    member: GroupRideMember(
      userId: '',
      userName: '',
      userPhotoUrl: '',
      joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
    color: kGroupRideMemberPalette.first,
    isMe: false,
    position: null,
    lastUpdate: null,
  );

  bool get isPending => member.status == GroupRideMemberStatus.pending;
  bool get isDeclined => member.status == GroupRideMemberStatus.declined;

  Duration? get age =>
      lastUpdate == null ? null : DateTime.now().difference(lastUpdate!);

  bool get isStale {
    final a = age;
    return a == null || a > kGroupRideStaleAfter;
  }

  String get initial {
    final name = member.userName.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  /// Human "last seen" text. Never claims a position is current when it
  /// isn't: no timestamp at all reads as "position age unknown", not "now".
  String get lastSeenLabel {
    if (position == null) return 'no position yet';
    final a = age;
    if (a == null) return 'position age unknown';
    if (a.inSeconds < 10) return 'live';
    if (a.inSeconds < 60) return 'last seen ${a.inSeconds}s ago';
    if (a.inMinutes < 60) return 'last seen ${a.inMinutes}m ago';
    return 'last seen ${a.inHours}h ago';
  }
}

class _MemberMarker extends StatelessWidget {
  final _MemberView view;
  const _MemberMarker({required this.view});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A stale marker is drawn washed out rather than removed — "he was
        // here 40 seconds ago" is useful; silently showing it as current is
        // not.
        color: view.isStale
            ? view.color.withValues(alpha: 0.45)
            : view.color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
        ],
      ),
      child: Text(
        view.initial,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: onMemberColor(view.color),
        ),
      ),
    );

    if (!view.isMe) return Center(child: dot);

    // The signed-in rider gets a ring around their dot so they can find
    // themselves in a cluster of similarly-sized markers at a glance.
    return Center(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: view.color, width: 2),
          color: Colors.white.withValues(alpha: 0.35),
        ),
        child: dot,
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  final List<_MemberView> members;

  const _MemberList({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      // Shouldn't happen (the creator is always a member) but a roster that
      // came back empty must render as an explanation, not an empty void.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Text(
            'Nobody is on this ride yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final joined = members.where((m) => !m.isPending && !m.isDeclined).toList();
    final pending = members.where((m) => m.isPending).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        children: [
          Text(
            'Riding — ${joined.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          for (final m in joined) _MemberRow(view: m),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Invited — ${pending.length} waiting',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final m in pending) _MemberRow(view: m),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final _MemberView view;
  const _MemberRow({required this.view});

  @override
  Widget build(BuildContext context) {
    final subtitle = view.isPending
        ? 'Hasn\'t joined yet'
        : view.isDeclined
            ? 'Declined'
            : view.lastSeenLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: view.isPending
                  ? view.color.withValues(alpha: 0.25)
                  : view.color,
            ),
            child: Text(
              view.initial,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: onMemberColor(view.color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              view.isMe ? '${view.member.userName} (you)' : view.member.userName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: (!view.isPending && !view.isDeclined && view.isStale)
                  ? AppColors.attention
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  const _Banner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.attention.withValues(alpha: 0.14),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.attention),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPositionsHint extends StatelessWidget {
  const _NoPositionsHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Waiting for the first position…',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
