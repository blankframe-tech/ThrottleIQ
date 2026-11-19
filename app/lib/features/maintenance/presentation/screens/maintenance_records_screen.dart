import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/service_visit.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/maintenance_format.dart';
import '../widgets/maintenance_log_tile.dart';
import '../widgets/maintenance_settings_section.dart';
import '../widgets/money_card.dart';
import '../widgets/paperwork_card.dart';

/// The look-back half of maintenance: what it costs, the fuel log, legal
/// paperwork and past visits. Kept off the main screen, which only answers
/// "what do I do next?".
class MaintenanceRecordsScreen extends ConsumerStatefulWidget {
  final String bikeId;
  const MaintenanceRecordsScreen({super.key, required this.bikeId});

  @override
  ConsumerState<MaintenanceRecordsScreen> createState() =>
      _MaintenanceRecordsScreenState();
}

class _MaintenanceRecordsScreenState
    extends ConsumerState<MaintenanceRecordsScreen> {
  int _historyShown = 5;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final imperial = ref.watch(maintenanceImperialProvider);
    final bikes = ref.watch(garageProvider).valueOrNull ?? [];
    final active = ref.watch(activeBikeProvider);
    // Deep links may omit bikeId: fall back to the active bike.
    final bike = widget.bikeId.isEmpty
        ? active
        : bikes.where((b) => b.id == widget.bikeId).firstOrNull;
    if (bike == null) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(backgroundColor: palette.background),
      );
    }
    final id = bike.id;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          bikes.length > 1
              ? '${bike.displayName} · ${context.l10n.maintRecordsTitle}'
                  .toUpperCase()
              : context.l10n.maintRecordsTitle.toUpperCase(),
          style: AppTypography.display(context, 16, weight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingMd, 8, AppDimensions.paddingMd, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyCard(bikeId: id, imperial: imperial),
              const SizedBox(height: 14),
              _buildFuelLink(id),
              const SizedBox(height: 14),
              PaperworkCard(bikeId: id),
              const SizedBox(height: 20),
              _buildHistory(id, imperial),
              const SizedBox(height: 24),
              // Reminders, adaptation, reset and running-cost settings.
              MaintenanceSettingsSection(bike: bike),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuelLink(String bikeId) {
    final palette = context.palette;
    return EditorialCard(
      key: const Key('maintenanceFuelLink'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/home/maintenance/fuel?bikeId=$bikeId'),
      child: Row(
        children: [
          Icon(Icons.local_gas_station_outlined, color: palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.l10n.fuelLogTitle,
                style: AppTypography.display(context, 15, letterSpacing: 0)),
          ),
          Icon(Icons.chevron_right, color: palette.textTertiary),
        ],
      ),
    );
  }

  Widget _buildHistory(String bikeId, bool imperial) {
    final logsAsync = ref.watch(maintenanceProvider(bikeId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EditorialLabel(context.l10n.serviceHistory),
            logsAsync.maybeWhen(
              data: (logs) {
                final totalCost = totalSpend(logs);
                if (totalCost <= 0) return const SizedBox.shrink();
                return Text(
                  context.l10n.total(groupThousands(totalCost)),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.palette.primary,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        logsAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: context.palette.primary)),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(maintenanceProvider(bikeId)),
          ),
          data: (logs) {
            final visits = groupVisits(logs);
            if (visits.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history,
                          color: context.palette.textTertiary, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.noServiceRecordsLogged,
                        style: TextStyle(
                            color: context.palette.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.whenServiceBikeLog,
                        style: TextStyle(
                            color: context.palette.textTertiary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }
            final shown = visits.take(_historyShown).toList();
            return Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  VisitTile(visit: shown[i], imperial: imperial),
                ],
                if (visits.length > shown.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () => setState(() => _historyShown += 10),
                      child: Text(
                        context.l10n
                            .showMoreVisits(visits.length - shown.length),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.palette.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
