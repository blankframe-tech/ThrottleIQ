import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../providers/ride_recording_provider.dart';

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBike = ref.watch(activeBikeProvider);
    final rideState = ref.watch(rideRecordingProvider);

    // If actively recording, push to active ride screen
    if (rideState.status == RecordingStatus.active ||
        rideState.status == RecordingStatus.paused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/ride/active');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Record Ride')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active bike card
              if (activeBike != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.two_wheeler, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeBike.displayName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            if (activeBike.cc != null)
                              Text('${activeBike.cc}cc',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/home/garage'),
                        child: const Text('Change',
                            style: TextStyle(fontSize: 13, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('No active bike selected',
                            style: TextStyle(color: AppColors.warning)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/home/garage/add'),
                        child: const Text('Add Bike'),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Recent rides summary
              if (activeBike != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _QuickStat(
                      value: SpeedFormatter.distanceKm(activeBike.totalDistanceM),
                      label: 'Total km',
                    ),
                    Container(width: 1, height: 36, color: AppColors.border),
                    _QuickStat(
                      value: '${activeBike.rideCount}',
                      label: 'Rides',
                    ),
                    Container(width: 1, height: 36, color: AppColors.border),
                    _QuickStat(
                      value: activeBike.lastRideAt != null
                          ? '${DateTime.now().difference(activeBike.lastRideAt!).inDays}d'
                          : '—',
                      label: 'Last ride',
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              // Hold to start button
              Center(child: _HoldToStartButton(enabled: activeBike != null)),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Hold to start recording',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
              ),

              if (rideState.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Text(rideState.error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  const _QuickStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _HoldToStartButton extends ConsumerStatefulWidget {
  final bool enabled;
  const _HoldToStartButton({required this.enabled});

  @override
  ConsumerState<_HoldToStartButton> createState() => _HoldToStartButtonState();
}

class _HoldToStartButtonState extends ConsumerState<_HoldToStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _holding) {
        _triggerStart();
      }
    });
  }

  void _triggerStart() async {
    setState(() => _holding = false);
    _ctrl.reset();
    await ref.read(rideRecordingProvider.notifier).startRide();
    if (mounted && ref.read(rideRecordingProvider).status == RecordingStatus.active) {
      context.go('/ride/active');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStarting = ref.watch(rideRecordingProvider).status == RecordingStatus.starting;

    return GestureDetector(
      onLongPressStart: widget.enabled
          ? (_) {
              setState(() => _holding = true);
              _ctrl.forward();
            }
          : null,
      onLongPressEnd: (_) {
        if (_holding) {
          setState(() => _holding = false);
          _ctrl.reset();
        }
      },
      onLongPressCancel: () {
        if (_holding) {
          setState(() => _holding = false);
          _ctrl.reset();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring
            if (_holding)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Container(
                  width: 160 + _ctrl.value * 30,
                  height: 160 + _ctrl.value * 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3 * (1 - _ctrl.value)),
                      width: 2,
                    ),
                  ),
                ),
              ),
            // Main button
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.enabled
                    ? (_holding ? AppColors.primaryDark : AppColors.primary)
                    : AppColors.textTertiary,
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(_holding ? 0.6 : 0.3),
                          blurRadius: _holding ? 30 : 16,
                          spreadRadius: _holding ? 4 : 0,
                        ),
                      ]
                    : null,
              ),
              child: isStarting
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.radio_button_checked,
                            color: Colors.white, size: 36),
                        const SizedBox(height: 6),
                        Text(
                          _holding ? 'Starting...' : 'HOLD',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
