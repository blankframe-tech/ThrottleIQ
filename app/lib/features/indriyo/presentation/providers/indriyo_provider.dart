import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/indriyo_models.dart';

const String kIndriyoDefaultStreamUrl = 'http://192.168.4.1:81/stream';

/// Settings → Advanced → Indriyo. Off by default, so riders without the
/// mirror hardware never see the HUD; the demo simulation (fake collision
/// alerts) is a separate opt-in.
class IndriyoSettings {
  final bool enabled;
  final bool isHudVisible;
  final bool isSimulationMode;
  final String streamUrl;
  final bool audioAlertsEnabled;

  const IndriyoSettings({
    this.enabled = false,
    this.isHudVisible = false,
    this.isSimulationMode = false,
    this.streamUrl = kIndriyoDefaultStreamUrl,
    this.audioAlertsEnabled = true,
  });

  IndriyoSettings copyWith({
    bool? enabled,
    bool? isHudVisible,
    bool? isSimulationMode,
    String? streamUrl,
    bool? audioAlertsEnabled,
  }) {
    return IndriyoSettings(
      enabled: enabled ?? this.enabled,
      isHudVisible: isHudVisible ?? this.isHudVisible,
      isSimulationMode: isSimulationMode ?? this.isSimulationMode,
      streamUrl: streamUrl ?? this.streamUrl,
      audioAlertsEnabled: audioAlertsEnabled ?? this.audioAlertsEnabled,
    );
  }
}

class IndriyoNotifier extends StateNotifier<IndriyoThreatState> {
  final Ref ref;
  Timer? _simTimer;
  double _simDistance = 35.0;
  bool _simApproaching = true;

  IndriyoNotifier(this.ref) : super(const IndriyoThreatState()) {
    _startSimulation();
  }

  void toggleHud() => ref.read(indriyoSettingsProvider.notifier).toggleHud();

  void setStreamConnected(bool connected) {
    state = state.copyWith(isConnected: connected);
  }

  void updateThreatState(IndriyoThreatState newState) {
    state = newState;
  }

  void _startSimulation() {
    _simTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      final settings = ref.read(indriyoSettingsProvider);
      if (!settings.isSimulationMode || !settings.isHudVisible) return;

      if (_simApproaching) {
        _simDistance -= 1.8;
        if (_simDistance <= 3.0) {
          _simApproaching = false;
        }
      } else {
        _simDistance += 3.5;
        if (_simDistance >= 40.0) {
          _simApproaching = true;
        }
      }

      final relSpeed = _simApproaching ? 28.0 : -10.0;
      final ttc = _simApproaching ? (_simDistance / (relSpeed / 3.6)) : 99.0;

      ThreatLevel threat = ThreatLevel.clear;
      bool leftBs = false;
      bool rightBs = false;
      bool crit = false;

      if (ttc < 1.8 && relSpeed > 10) {
        threat = ThreatLevel.critical;
        crit = true;
      } else if (_simDistance < 8.0) {
        threat = ThreatLevel.warning;
        leftBs = true;
      } else if (ttc < 3.5) {
        threat = ThreatLevel.warning;
      } else {
        threat = ThreatLevel.clear;
      }

      state = state.copyWith(
        highestThreat: threat,
        leftBlindSpotActive: leftBs,
        rightBlindSpotActive: rightBs,
        criticalCollision: crit,
        minTtc: ttc < 90 ? ttc : -1.0,
        fps: 29.5,
        latencyMs: 18.0,
        isConnected: true,
      );
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }
}

/// Saved in SharedPreferences, except [IndriyoSettings.isHudVisible], which
/// is per ride.
class IndriyoSettingsNotifier extends StateNotifier<IndriyoSettings> {
  IndriyoSettingsNotifier() : super(const IndriyoSettings()) {
    _load();
  }

  static const _kEnabled = 'indriyo_enabled';
  static const _kStreamUrl = 'indriyo_stream_url';
  static const _kSimulation = 'indriyo_simulation';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      enabled: prefs.getBool(_kEnabled),
      streamUrl: prefs.getString(_kStreamUrl),
      isSimulationMode: prefs.getBool(_kSimulation),
    );
  }

  void toggleHud() => state = state.copyWith(isHudVisible: !state.isHudVisible);

  /// Turning Indriyo off also hides the HUD.
  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v, isHudVisible: v && state.isHudVisible);
    await (await SharedPreferences.getInstance()).setBool(_kEnabled, v);
  }

  Future<void> setStreamUrl(String url) async {
    state = state.copyWith(streamUrl: url);
    await (await SharedPreferences.getInstance()).setString(_kStreamUrl, url);
  }

  Future<void> setSimulationMode(bool v) async {
    state = state.copyWith(isSimulationMode: v);
    await (await SharedPreferences.getInstance()).setBool(_kSimulation, v);
  }
}

final indriyoSettingsProvider =
    StateNotifierProvider<IndriyoSettingsNotifier, IndriyoSettings>(
        (ref) => IndriyoSettingsNotifier());

final indriyoProvider =
    StateNotifierProvider<IndriyoNotifier, IndriyoThreatState>((ref) {
  return IndriyoNotifier(ref);
});
