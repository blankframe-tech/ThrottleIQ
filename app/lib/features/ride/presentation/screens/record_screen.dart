import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../providers/ride_recording_provider.dart';

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBike = ref.watch(activeBikeProvider);
    final rideState = ref.watch(rideRecordingProvider);
    final name = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first;

    // If actively recording, push to active ride screen
    if (rideState.status == RecordingStatus.active ||
        rideState.status == RecordingStatus.paused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/ride/active');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 8,
              AppDimensions.paddingMd, AppDimensions.paddingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: settings only (editorial has no chrome title here)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                ),
              ),
              const SizedBox(height: 4),

              // Black hero panel
              InkPanel(
                padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.onInk, width: 2),
                      ),
                      child: const Icon(Icons.speed, color: AppColors.onInk, size: 34),
                    ),
                    const SizedBox(height: 24),
                    Text('Your ride,',
                        textAlign: TextAlign.center,
                        style: display(30, color: AppColors.onInk, height: 1.1)),
                    Text('smarter.',
                        textAlign: TextAlign.center,
                        style: display(30, color: AppColors.onInk, height: 1.1)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Greeting card
              EditorialCard(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(),
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(name ?? 'Rider', style: display(22)),
                        ],
                      ),
                    ),
                    if (activeBike != null && activeBike.rideCount > 0)
                      EditorialPill('${activeBike.rideCount} rides',
                          tone: PillTone.accent),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bike card / no-bike warning
              if (activeBike != null)
                EditorialCard(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  onTap: () => context.go('/home/garage'),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: const Icon(Icons.two_wheeler,
                            color: AppColors.textPrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeBike.displayName,
                                style: display(16, letterSpacing: 0)),
                            const SizedBox(height: 2),
                            const Text('Ready to ride',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Text('Change',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ],
                  ),
                )
              else
                EditorialCard(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  borderColor: AppColors.attention,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.attention),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('No active bike selected',
                            style: TextStyle(color: AppColors.textPrimary)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/home/garage/add'),
                        child: const Text('Add Bike'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Stat chips
              if (activeBike != null)
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        value: SpeedFormatter.distanceKm(activeBike.totalDistanceM),
                        label: 'total km',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        value: '${activeBike.rideCount}',
                        label: 'rides',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        value: activeBike.lastRideAt != null
                            ? '${DateTime.now().difference(activeBike.lastRideAt!).inDays}d'
                            : '—',
                        label: 'last ride',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Start ride (hold) button
              _HoldToStartButton(enabled: activeBike != null),
              const SizedBox(height: 10),
              const Center(
                child: Text('Hold to start recording',
                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ),

              if (rideState.error != null) ...[
                const SizedBox(height: 16),
                EditorialCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.danger,
                  child: Text(rideState.error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: display(20)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
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
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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

  void _cancel() {
    if (_holding) {
      setState(() => _holding = false);
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStarting =
        ref.watch(rideRecordingProvider).status == RecordingStatus.starting;
    final enabled = widget.enabled && !isStarting;

    return GestureDetector(
      onLongPressStart: enabled
          ? (_) {
              setState(() => _holding = true);
              _ctrl.forward();
            }
          : null,
      onLongPressEnd: (_) => _cancel(),
      onLongPressCancel: _cancel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: SizedBox(
          height: 60,
          child: Stack(
            children: [
              Container(
                color: enabled ? AppColors.ink : AppColors.textTertiary,
              ),
              // hold progress fill
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => FractionallySizedBox(
                  widthFactor: _ctrl.value,
                  alignment: Alignment.centerLeft,
                  child: Container(color: AppColors.primary),
                ),
              ),
              Center(
                child: isStarting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_holding ? 'Keep holding…' : 'Start Ride',
                              style: display(17,
                                  color: AppColors.onInk, letterSpacing: 0.2)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward,
                              color: AppColors.onInk, size: 20),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
