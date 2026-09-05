import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/indriyo_models.dart';
import '../../data/mjpeg_stream_service.dart';
import '../providers/indriyo_provider.dart';

/// The Indriyo Digital Rearview Mirror HUD for ThrottleIQ.
/// Displays live video with peripheral warning borders (Amber / Flashing Red),
/// active vehicle vectoring, and motorcycle telemetry.
class IndriyoMirrorHud extends ConsumerStatefulWidget {
  final double currentSpeedKmh;
  final VoidCallback? onClose;

  const IndriyoMirrorHud({
    super.key,
    required this.currentSpeedKmh,
    this.onClose,
  });

  @override
  ConsumerState<IndriyoMirrorHud> createState() => _IndriyoMirrorHudState();
}

class _IndriyoMirrorHudState extends ConsumerState<IndriyoMirrorHud>
    with SingleTickerProviderStateMixin {
  MjpegStreamService? _streamService;
  Uint8List? _liveFrame;
  late AnimationController _flashController;
  ThreatLevel _lastThreat = ThreatLevel.clear;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..repeat(reverse: true);

    final settings = ref.read(indriyoSettingsProvider);
    if (!settings.isSimulationMode) {
      _initStream(settings.streamUrl);
    }
  }

  void _initStream(String url) {
    _streamService?.dispose();
    _streamService = MjpegStreamService(streamUrl: url);
    _streamService!.frameStream.listen((frame) {
      if (mounted) {
        setState(() {
          _liveFrame = frame;
        });
      }
    });
    _streamService!.start();
  }

  @override
  void dispose() {
    _streamService?.dispose();
    _flashController.dispose();
    super.dispose();
  }

  Color _getBorderColor(ThreatLevel threat) {
    if (threat == ThreatLevel.critical) {
      return _flashController.value > 0.5
          ? const Color(0xFFFF2A4B)
          : const Color(0x66FF2A4B);
    } else if (threat == ThreatLevel.warning) {
      return const Color(0xFFFF9D00); // Amber
    } else {
      return const Color(0x3330D158); // Subtle emerald
    }
  }

  @override
  Widget build(BuildContext context) {
    final threatState = ref.watch(indriyoProvider);
    final settings = ref.watch(indriyoSettingsProvider);

    // Haptic feedback triggers on threat escalation
    if (threatState.highestThreat != _lastThreat) {
      _lastThreat = threatState.highestThreat;
      if (_lastThreat == ThreatLevel.critical) {
        HapticFeedback.heavyImpact();
      } else if (_lastThreat == ThreatLevel.warning) {
        HapticFeedback.mediumImpact();
      }
    }

    final borderColor = _getBorderColor(threatState.highestThreat);

    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 190,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF070A10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: threatState.highestThreat == ThreatLevel.critical ? 5 : 2.5,
            ),
            boxShadow: [
              if (threatState.highestThreat != ThreatLevel.clear)
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live Frame or Simulated Mirror Canvas
              if (_liveFrame != null)
                Image.memory(
                  _liveFrame!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              else
                _buildSimulatedMirrorBackground(threatState),

              // 2. Left Blind Spot Peripheral Indicator
              if (threatState.leftBlindSpotActive)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 14,
                    height: double.infinity,
                    color: const Color(0xFFFF9D00),
                  ),
                ),

              // 3. Right Blind Spot Peripheral Indicator
              if (threatState.rightBlindSpotActive)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 14,
                    height: double.infinity,
                    color: const Color(0xFFFF9D00),
                  ),
                ),

              // 4. Top Telemetry Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC06090E), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9D00),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'INDRIYO',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            settings.isSimulationMode ? 'DEMO SIMULATOR' : 'LIVE TAIL CAM',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '${widget.currentSpeedKmh.toStringAsFixed(0)} KM/H',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Critical Emergency Center Strobe Banner
              if (threatState.criticalCollision && _flashController.value > 0.5)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2A4B),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Color(0x99FF2A4B), blurRadius: 16),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'COLLISION RISK! TTC ${threatState.minTtc.toStringAsFixed(1)}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 6. Bottom Status Readout
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: const Color(0xD906090E),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: threatState.highestThreat == ThreatLevel.critical
                                ? const Color(0xFFFF2A4B)
                                : (threatState.highestThreat == ThreatLevel.warning
                                    ? const Color(0xFFFF9D00)
                                    : const Color(0xFF30D158)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            threatState.highestThreat == ThreatLevel.critical
                                ? 'CRITICAL EVASION ALERT'
                                : (threatState.highestThreat == ThreatLevel.warning
                                    ? 'BLIND SPOT OCCUPIED'
                                    : 'MONITORING REAR CORRIDOR'),
                            style: TextStyle(
                              color: threatState.highestThreat == ThreatLevel.critical
                                  ? const Color(0xFFFF2A4B)
                                  : (threatState.highestThreat == ThreatLevel.warning
                                      ? const Color(0xFFFF9D00)
                                      : const Color(0xFF30D158)),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${threatState.fps.toStringAsFixed(0)} FPS | ${threatState.latencyMs.toStringAsFixed(0)}ms',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimulatedMirrorBackground(IndriyoThreatState threatState) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.2,
          colors: [Color(0xFF141A24), Color(0xFF070A10)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated Road Vanishing Lines
          CustomPaint(
            size: Size.infinite,
            painter: _SimulatedRoadPainter(),
          ),
          // Target Vehicle Hologram
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: threatState.highestThreat == ThreatLevel.critical
                        ? const Color(0xFFFF2A4B)
                        : (threatState.highestThreat == ThreatLevel.warning
                            ? const Color(0xFFFF9D00)
                            : const Color(0xFF00F0FF)),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    Icons.directions_car,
                    color: threatState.highestThreat == ThreatLevel.critical
                        ? const Color(0xFFFF2A4B)
                        : const Color(0xFF00F0FF),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  threatState.minTtc > 0
                      ? 'APPROACHING • TTC ${threatState.minTtc.toStringAsFixed(1)}s'
                      : 'TRACKING VEHICLE',
                  style: TextStyle(
                    color: threatState.highestThreat == ThreatLevel.critical
                        ? const Color(0xFFFF2A4B)
                        : const Color(0xFF00F0FF),
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimulatedRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x2200F0FF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final vanishY = size.height * 0.35;
    final centerX = size.width * 0.5;

    // Road lane boundary lines
    canvas.drawLine(Offset(centerX, vanishY), Offset(size.width * 0.1, size.height), paint);
    canvas.drawLine(Offset(centerX, vanishY), Offset(size.width * 0.9, size.height), paint);

    // Center dash line
    final dashPaint = Paint()
      ..color = const Color(0x44FFFFFF)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(centerX, vanishY), Offset(centerX, size.height), dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
