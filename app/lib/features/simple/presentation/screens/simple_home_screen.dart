import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/bike_colors.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_modules.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../maintenance/domain/entities/fuel_log.dart';
import '../../../maintenance/presentation/providers/fuel_provider.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../ride/presentation/widgets/bike_picker_card.dart';
import '../../domain/mileage_verdict.dart';
import '../providers/simple_bike_provider.dart';
import '../widgets/simple_home_help_sheet.dart';
import '../widgets/simple_rides_empty_state.dart';
import '../widgets/simple_rides_format.dart';
import '../widgets/simple_section.dart';
import '../widgets/simple_settings_button.dart';
import '../widgets/simple_start_ride_button.dart';
import '../widgets/simple_theme.dart';

/// Simple mode Home tab (#241), laid out like the full app's Record screen:
/// the bike's photo, this month's km and fuel spend under it, the mileage
/// verdict, and the round hold-to-start ring pinned at the bottom.
class SimpleHomeScreen extends ConsumerWidget {
  const SimpleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final garage = ref.watch(garageProvider);
    final bike = ref.watch(simpleBikeProvider);
    return SimpleTheme(
      child: Scaffold(
        // No title: the bike's photo below is the header, as on Record.
        appBar: AppBar(
          actions: const [SimpleEmergencyButton(), SimpleSettingsButton()],
        ),
        body: garage.isLoading && !garage.hasValue
            ? const Center(child: CircularProgressIndicator())
            : bike == null
                ? ListView(children: [
                    SimpleEmptyState(
                      icon: Icons.two_wheeler,
                      title: l10n.simpleBikeNoBikeTitle,
                      body: l10n.simpleHomeNoBike,
                      action: l10n.addBike,
                      onPressed: () => context.push('/home/profile/add'),
                    ),
                  ])
                : _HomeBody(bike: bike),
      ),
    );
  }
}

/// A tile whose source is loading or failed: never a made-up 0.
const _noValue = '—';

class _HomeBody extends ConsumerWidget {
  final BikeEntity bike;
  const _HomeBody({required this.bike});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rideTracking =
        ref.watch(appModulesProvider.select((m) => m.rideTracking));
    final rides = ref.watch(rideHistoryProvider(bike.id)).valueOrNull;
    final fills = ref.watch(fuelLogsProvider(bike.id)).valueOrNull;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month);
    final to = DateTime(now.year, now.month + 1);
    bool thisMonth(DateTime t) => !t.isBefore(from) && t.isBefore(to);

    final km = (rides ?? const <RideEntity>[])
            .where((r) =>
                (r.status == RideStatus.completed ||
                    r.status == RideStatus.crash) &&
                thisMonth(r.startTime))
            .fold<double>(0, (s, r) => s + r.distanceM) /
        1000;
    final taka = (fills ?? const [])
        .where((f) => thisMonth(f.filledAt))
        .fold<double>(0, (s, f) => s + f.totalCost);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              // The full app's hero; with two bikes, tap it to switch.
              BikePickerCard(
                activeBike: bike,
                accentColor: bikeHasPhoto(bike) ? bikeAccentColor(bike) : null,
              ),
              const SizedBox(height: 8),
              SimpleSectionHeader(l10n.simpleHomeThisMonth),
              SimpleTileGrid(children: [
                // km comes only from recorded rides: with tracking off it
                // would always read 0, so it isn't shown.
                if (rideTracking)
                  SimpleStatTile(
                    key: const Key('simple_home_km'),
                    value: rides == null ? _noValue : simpleAmount(km),
                    label: l10n.simpleHomeKmRidden,
                  ),
                SimpleStatTile(
                  key: const Key('simple_home_taka'),
                  value: fills == null ? _noValue : '৳${simpleAmount(taka)}',
                  label: l10n.simpleHomeFuelSpent,
                ),
              ]),
              if (fills != null) ...[
                const SizedBox(height: 12),
                _MileageCard(fills: fills),
              ],
            ],
          ),
        ),
        // Pinned, as on Record: always under the thumb, never scrolled off.
        if (rideTracking)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SimpleStartRideButton(bike: bike),
          ),
      ],
    );
  }
}

/// The mileage verdict as a card row, or why there isn't one yet.
class _MileageCard extends StatelessWidget {
  final List<FuelLogEntity> fills;
  const _MileageCard({required this.fills});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    if (fills.isEmpty) {
      return _row(
        context,
        key: const Key('simple_home_no_fuel'),
        icon: Icons.local_gas_station_outlined,
        color: palette.textTertiary,
        children: [
          Text(l10n.simpleHomeNoFuel,
              style: TextStyle(color: palette.textSecondary)),
        ],
      );
    }
    final reading = mileageVerdict(fills);
    String n(double v) => v.toStringAsFixed(v >= 10 ? 0 : 1);
    final last = reading.lastKmPerLiter;
    final avg = reading.avgKmPerLiter;
    final (text, color) = switch (reading.verdict) {
      MileageVerdict.notEnoughData => (l10n.simpleHomeMileageNotEnough, null),
      MileageVerdict.firstOnly => (l10n.simpleHomeMileageFirst(n(last!)), null),
      MileageVerdict.good => (
          l10n.simpleHomeMileageGood(n(last!)),
          palette.success
        ),
      MileageVerdict.okay => (l10n.simpleHomeMileageOkay(n(last!)), null),
      MileageVerdict.low => (
          l10n.simpleHomeMileageLow(n(last!)),
          palette.attention
        ),
    };
    return _row(
      context,
      key: const Key('simple_home_mileage'),
      icon: Icons.speed,
      color: color ?? palette.textSecondary,
      children: [
        Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color ?? palette.textPrimary)),
        if (reading.verdict case MileageVerdict.okay || MileageVerdict.low)
          Text(l10n.simpleHomeMileageAverage(n(avg!)),
              style: TextStyle(color: palette.textSecondary)),
      ],
    );
  }

  static Widget _row(BuildContext context,
          {required Key key,
          required IconData icon,
          required Color color,
          required List<Widget> children}) =>
      EditorialCard(
        key: key,
        radius: context.shape.radiusLg,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      );
}
