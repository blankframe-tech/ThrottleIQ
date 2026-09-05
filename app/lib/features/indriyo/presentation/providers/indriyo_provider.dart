import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/indriyo_models.dart';

class IndriyoSettings {
  final bool isHudVisible;
  final bool isSimulationMode;
  final String streamUrl;
  final bool audioAlertsEnabled;

  const IndriyoSettings({
    this.isHudVisible = false,
    this.isSimulationMode = true, // Default to demo simulation so user can test immediately
    this.streamUrl = 'http://192.168.4.1:81/stream',
    this.audioAlertsEnabled = true,
  });

  IndriyoSettings copyWith({
    bool? isHudVisible,
    bool? isSimulationMode,
    String? streamUrl,
    bool? audioAlertsEnabled,
  }) {
    return IndriyoSettings(
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

  void toggleHud() {
    final settings = ref.read(indriyoSettingsProvider);
    ref.read(indriyoSettingsProvider.notifier).state =
        settings.copyWith(isHudVisible: !settings.isHudVisible);
  }

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

final indriyoSettingsProvider =
    StateProvider<IndriyoSettings>((ref) => const IndriyoSettings());

final indriyoProvider =
    StateNotifierProvider<IndriyoNotifier, IndriyoThreatState>((ref) {
  return IndriyoNotifier(ref);
});
