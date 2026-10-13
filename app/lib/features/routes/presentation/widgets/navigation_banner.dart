import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/turn_instruction.dart';
import '../nav_format.dart';
import '../providers/navigation_session_provider.dart';
import '../screens/route_detail_screen.dart' show turnIcon;
import '../turn_instruction_l10n.dart';

/// Turn guidance drawn over the active-ride cockpit.
///
/// Renders nothing at all when no route is being followed, so
/// `ActiveRideScreen` can host it unconditionally — the cockpit shouldn't have
/// to know whether this ride started from a route or from the Record button.
///
/// The ride's own controls stay exactly where they were: the only thing this
/// adds is a band at the top, and a close button that drops guidance while
/// leaving the recording running.
class NavigationBanner extends ConsumerWidget {
  const NavigationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(navigationSessionProvider);
    if (!session.isActive) return const SizedBox.shrink();

    final turn = session.currentTurn;
    final progress = session.progress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Card(
          child: Row(
            children: [
              Icon(
                progress.arrived
                    ? Icons.flag_outlined
                    : turnIcon(turn?.kind ?? TurnKind.start),
                size: 30,
                color: context.palette.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.arrived
                          ? context.l10n.navArrivedStillRecording
                          : (turn?.localizedText(context.l10n) ??
                              session.route!.name),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    if (!progress.arrived && progress.metresToTurn != null)
                      Text(
                        context.l10n
                            .navInDistance(routeDistanceLabel(progress.metresToTurn!)),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!progress.arrived) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      routeDistanceLabel(progress.metresRemaining),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    Text(
                      routeEtaLabel(context.l10n, progress.etaSeconds),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
              IconButton(
                onPressed: () {
                  ref.read(navigationSessionProvider.notifier).stop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.l10n.navGuidanceStoppedStillRecording)),
                  );
                },
                icon: Icon(Icons.close, size: 20, color: context.palette.textSecondary),
                tooltip: context.l10n.navStopGuidance,
              ),
            ],
          ),
        ),
        if (progress.isOffRoute) ...[
          const SizedBox(height: 8),
          _Card(
            background: context.palette.danger.withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: context.palette.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.offRouteFromLine(
                        routeDistanceLabel(progress.offRouteM!)),
                    style: TextStyle(
                        fontSize: 13, color: context.palette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Trailing gap rather than one owned by the cockpit's Column: this
        // widget renders nothing when no route is being followed, and the
        // spacing has to disappear with it.
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? background;
  const _Card({required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // Opaque enough to stay readable over the map and over the pause dim.
        color: background ?? context.palette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: child,
    );
  }
}
