import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../screens/onboarding_manifest.dart';

/// Renders a real, high-fidelity UI mockup with callout pointer pins for each feature.
class OnboardingUiMockup extends StatefulWidget {
  const OnboardingUiMockup({
    super.key,
    required this.featureKey,
    required this.accentColor,
    required this.pointers,
  });

  final String featureKey;
  final Color accentColor;
  final List<SlidePointer> pointers;

  @override
  State<OnboardingUiMockup> createState() => _OnboardingUiMockupState();
}

class _OnboardingUiMockupState extends State<OnboardingUiMockup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int? _selectedPointer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 290),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.15),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            // ── Simulated screen content ──
            Positioned.fill(
              child: _buildScreenContent(widget.featureKey),
            ),

            // ── Pointer callouts overlay ──
            Positioned.fill(
              child: _buildPointersOverlay(),
            ),

            // ── Device frame top status bar ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildDeviceTopBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      color: Colors.black.withValues(alpha: 0.55),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          Row(
            children: [
              Icon(Icons.wifi, size: 11, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Icon(Icons.battery_full, size: 12, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointersOverlay() {
    if (widget.pointers.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulseScale = 1.0 + (_pulseController.value * 0.18);
        final pulseAlpha = 0.6 - (_pulseController.value * 0.4);

        return Stack(
          children: widget.pointers.map((pointer) {
            final alignment = _pointerAlignment(widget.featureKey, pointer.number);
            final isSelected = _selectedPointer == pointer.number;

            return Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPointer = isSelected ? null : pointer.number;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Pulsing Pin
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 24 * pulseScale,
                            height: 24 * pulseScale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.accentColor.withValues(alpha: pulseAlpha),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.accentColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${pointer.number}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Tooltip tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.accentColor
                              : Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: isSelected ? 1.0 : 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          pointer.title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Alignment _pointerAlignment(String key, int number) {
    switch (key) {
      case 'garage':
        if (number == 1) return const Alignment(-0.8, -0.25);
        if (number == 2) return const Alignment(0.8, -0.2);
        return const Alignment(0.0, 0.75);
      case 'ride_recording':
        if (number == 1) return const Alignment(-0.75, -0.3);
        if (number == 2) return const Alignment(0.0, 0.75);
        return const Alignment(0.75, -0.3);
      case 'auto_tracking':
        if (number == 1) return const Alignment(0.75, -0.35);
        if (number == 2) return const Alignment(-0.65, 0.25);
        return const Alignment(0.65, 0.75);
      case 'maintenance':
        if (number == 1) return const Alignment(-0.75, -0.35);
        if (number == 2) return const Alignment(0.75, 0.1);
        return const Alignment(-0.6, 0.75);
      case 'places':
        if (number == 1) return const Alignment(-0.6, -0.35);
        if (number == 2) return const Alignment(0.6, 0.75);
        return const Alignment(0.65, -0.3);
      case 'social_forums':
        if (number == 1) return const Alignment(-0.7, 0.65);
        if (number == 2) return const Alignment(0.7, -0.35);
        return const Alignment(0.65, 0.65);
      case 'profile':
      default:
        if (number == 1) return const Alignment(-0.75, -0.35);
        if (number == 2) return const Alignment(0.75, 0.2);
        return const Alignment(-0.6, 0.75);
    }
  }

  Widget _buildScreenContent(String key) {
    switch (key) {
      case 'garage':
        return _buildGarageScreen();
      case 'ride_recording':
        return _buildRideRecordingScreen();
      case 'auto_tracking':
        return _buildAutoTrackingScreen();
      case 'maintenance':
        return _buildMaintenanceScreen();
      case 'places':
        return _buildPlacesScreen();
      case 'social_forums':
        return _buildSocialScreen();
      case 'profile':
      default:
        return _buildProfileScreen();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. GARAGE SCREEN MOCKUP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGarageScreen() {
    return Container(
      color: const Color(0xFF14181B),
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Garage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.accentColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 12, color: widget.accentColor),
                    const SizedBox(width: 3),
                    Text(
                      'Add Bike',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bike Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E2429),
                    widget.accentColor.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Icon(Icons.two_wheeler, size: 34, color: widget.accentColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Yamaha MT-09',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.accentColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '890 CC · Triple Cylinder · 2024',
                              style: TextStyle(fontSize: 10, color: Colors.white60),
                            ),
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Icon(Icons.speed, size: 11, color: Colors.white38),
                                SizedBox(width: 4),
                                Text(
                                  '4,280 km logged',
                                  style: TextStyle(fontSize: 10, color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Service strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.build_outlined, size: 12, color: Colors.amberAccent),
                            SizedBox(width: 6),
                            Text(
                              'Oil & Filter Due in 720 km',
                              style: TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ],
                        ),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.amberAccent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Palette tint strip
          Row(
            children: [
              const Text(
                'Theme Tint:',
                style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
              const SizedBox(width: 8),
              _colorDot(const Color(0xFF4CAF50), isSelected: true),
              _colorDot(const Color(0xFFFF5722)),
              _colorDot(const Color(0xFF2196F3)),
              _colorDot(const Color(0xFFE91E63)),
              _colorDot(const Color(0xFFFF9800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color c, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. RIDE RECORDING COCKPIT MOCKUP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRideRecordingScreen() {
    return Container(
      color: const Color(0xFF0D1013),
      padding: const EdgeInsets.fromLTRB(14, 26, 14, 8),
      child: Column(
        children: [
          // Top HUD bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '10Hz GPS LOCKED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SHIELD: ARMED',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Speedometer Dial & Lean Arc
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Speed Gauge
              Column(
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '068',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: widget.accentColor,
                            letterSpacing: -2,
                          ),
                        ),
                        const TextSpan(
                          text: ' KM/H',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Row(
                    children: [
                      Text('AVG 52 · ', style: TextStyle(fontSize: 9, color: Colors.white38)),
                      Text('TOP 124', style: TextStyle(fontSize: 9, color: Colors.white60)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Lean Angle Arc Gauge
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text('LEAN ANGLE', style: TextStyle(fontSize: 8, color: Colors.white54)),
                    const SizedBox(height: 2),
                    Text(
                      '24° L',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text('MAX 38°', style: TextStyle(fontSize: 8, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),

          // Hold to record big pill button
          Container(
            width: 180,
            height: 38,
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'HOLD 1s TO START',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. AUTO TRACKING MOCKUP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAutoTrackingScreen() {
    return Container(
      color: const Color(0xFF13171A),
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Auto-Tracking Settings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: widget.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Filter card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.accentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 20, color: widget.accentColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Non-Ride Filter Active',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        'Walking, buses & subway rides automatically ignored',
                        style: TextStyle(fontSize: 9, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Auto-detected ride preview
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1D2328),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Detected Ride', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: const Text('AUTO SAVED', style: TextStyle(fontSize: 8, color: Colors.greenAccent, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Airport Express Way · 14.8 km · 22 mins', style: TextStyle(fontSize: 9, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. MAINTENANCE MOCKUP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMaintenanceScreen() {
    return Container(
      color: const Color(0xFF14171A),
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Maintenance Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('+ Log Service', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: widget.accentColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Item 1
          _maintenanceRow(
            title: 'Engine Oil & Filter',
            dueText: 'Due in 320 km',
            progress: 0.85,
            progressColor: Colors.amberAccent,
            isAlert: true,
          ),
          const SizedBox(height: 8),

          // Item 2
          _maintenanceRow(
            title: 'Chain Clean & Lube',
            dueText: 'Good for 850 km',
            progress: 0.25,
            progressColor: Colors.greenAccent,
            isAlert: false,
          ),
          const SizedBox(height: 8),

          // Item 3
          _maintenanceRow(
            title: 'Brake Fluid Flush',
            dueText: 'Good for 2,100 km',
            progress: 0.40,
            progressColor: Colors.greenAccent,
            isAlert: false,
          ),
        ],
      ),
    );
  }

  Widget _maintenanceRow({
    required String title,
    required String dueText,
    required double progress,
    required Color progressColor,
    required bool isAlert,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAlert ? progressColor.withValues(alpha: 0.4) : Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(
                dueText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isAlert ? Colors.amberAccent : Colors.white60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. PLACES MOCKUP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPlacesScreen() {
    return Container(
      color: const Color(0xFF101418),
      child: Stack(
        children: [
          // Simulated Map Graphic
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(accentColor: widget.accentColor),
            ),
          ),

          // Top POI tabs
          Positioned(
            top: 28,
            left: 14,
            right: 14,
            child: Row(
              children: [
                _poiChip('All', isSelected: true),
                _poiChip('⛽ Fuel'),
                _poiChip('🔧 Workshops'),
                _poiChip('☕ Cafes'),
              ],
            ),
          ),

          // Bottom POI card
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2026),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.4)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_gas_station, color: widget.accentColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tejgaon Padma Octane 95',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '★ 4.9 · Verified Pure Fuel · Open 24/7',
                          style: TextStyle(fontSize: 9, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Directions',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _poiChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? widget.accentColor : Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? widget.accentColor : Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. SOCIAL SCREEN MOCKUP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSocialScreen() {
    return Container(
      color: const Color(0xFF12161A),
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rider Feed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.group_add, size: 12, color: widget.accentColor),
                    const SizedBox(width: 4),
                    Text('PIN: TR-981', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: widget.accentColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Shared Ride Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 14, color: Colors.white)),
                      SizedBox(width: 8),
                      Text('Rahim K. · MT-15', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      Spacer(),
                      Text('2h ago', style: TextStyle(fontSize: 9, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Morning twisties through 300 Feet Highway!', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  const Spacer(),

                  // Polyline preview with privacy shield
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 12, color: widget.accentColor),
                            const SizedBox(width: 4),
                            const Text('Privacy Zone: 200m Endpoints Clipped', style: TextStyle(fontSize: 9, color: Colors.white70)),
                          ],
                        ),
                        const Text('54.2 km', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 7. PROFILE & SAFETY MOCKUP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildProfileScreen() {
    return Container(
      color: const Color(0xFF13171A),
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.accentColor.withValues(alpha: 0.25),
                child: Icon(Icons.person, color: widget.accentColor, size: 22),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Abraar · @blackbird', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('Road Captain · Dhaka Metro', style: TextStyle(fontSize: 9, color: Colors.white54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('18,420', 'KM RIDDEN'),
                _statCol('142', 'RIDES'),
                _statCol('98/100', 'SAFETY SCORE'),
              ],
            ),
          ),
          const Spacer(),

          // SafeQR & SOS card
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.accentColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code, color: widget.accentColor, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SafeQR Offline Medical Card', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Blood: O+ · ICE Emergency SOS Armed', style: TextStyle(fontSize: 8, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white38)),
      ],
    );
  }
}

/// Lightweight painter for the simulated map grid.
class _MapGridPainter extends CustomPainter {
  _MapGridPainter({required this.accentColor});
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Road curve
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.2, size.width, size.height * 0.5);
    canvas.drawPath(path, roadPaint);

    // Map pin circles
    void drawPin(Offset center, Color color) {
      canvas.drawCircle(center, 9, Paint()..color = color);
      canvas.drawCircle(center, 4, Paint()..color = Colors.black);
    }

    drawPin(Offset(size.width * 0.35, size.height * 0.45), accentColor);
    drawPin(Offset(size.width * 0.7, size.height * 0.35), Colors.amberAccent);
    drawPin(Offset(size.width * 0.82, size.height * 0.65), Colors.cyanAccent);
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}
