import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_modules.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../maintenance/presentation/providers/fuel_provider.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../ride/presentation/widgets/recording_gate.dart';
import '../../domain/mileage_verdict.dart';
import '../providers/simple_bike_provider.dart';
import '../widgets/simple_home_alert.dart';
import '../widgets/simple_home_help_sheet.dart';
import '../widgets/simple_rides_format.dart';
import '../widgets/simple_settings_button.dart';

/// Simple mode Home tab (#241): one bike, one big button, this month's km
/// and fuel spend, a mileage verdict and at most one alert.
class SimpleHomeScreen extends ConsumerWidget {
  const SimpleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    final bike = ref.watch(simpleBikeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(bike?.displayName ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [SimpleSettingsButton()],
      ),
      body: garage.isLoading && !garage.hasValue
          ? const Center(child: CircularProgressIndicator())
          : bike == null
              ? _NoBike()
              : _HomeBody(bike: bike),
    );
  }
}

/// Buttons here are at least 48dp tall.
const _tall = Size(64, 48);

/// A tile whose source is loading or failed: never a made-up 0.
const _noValue = '—';

class _NoBike extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.l10n.simpleHomeNoBike,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('simple_home_add_bike'),
            style: FilledButton.styleFrom(minimumSize: _tall),
            onPressed: () => context.push('/home/profile/add'),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addBike),
          ),
        ],
      );
}

class _HomeBody extends ConsumerWidget {
  final BikeEntity bike;
  const _HomeBody({required this.bike});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final modules = ref.watch(appModulesProvider);
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (modules.rideTracking) ...[
          _StartRideButton(bike: bike),
          if (rides != null && rides.isEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.simpleHomeNoRides,
                key: const Key('simple_home_no_rides')),
          ],
          const SizedBox(height: 16),
        ],
        SimpleHomeAlert(bike: bike, places: modules.places),
        Text(l10n.simpleHomeThisMonth,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // km comes only from recorded rides: with tracking off it would
            // always read 0, so it isn't shown.
            if (modules.rideTracking) ...[
              Expanded(
                child: _Tile(
                  key: const Key('simple_home_km'),
                  value: rides == null ? _noValue : simpleAmount(km),
                  label: l10n.simpleHomeKmRidden,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _Tile(
                key: const Key('simple_home_taka'),
                value: fills == null ? _noValue : '৳${simpleAmount(taka)}',
                label: l10n.simpleHomeFuelSpent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (fills != null && fills.isEmpty)
          Text(l10n.simpleHomeNoFuel, key: const Key('simple_home_no_fuel'))
        else if (fills != null)
          _MileageLine(reading: mileageVerdict(fills)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                key: const Key('simple_home_add_fuel'),
                style: FilledButton.styleFrom(minimumSize: _tall),
                onPressed: () => context
                    .push('/home/maintenance/fuel/add?bikeId=${bike.id}'),
                icon: const Icon(Icons.local_gas_station),
                label: Text(l10n.simpleHomeAddFuel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('simple_home_help'),
                style: FilledButton.styleFrom(
                  minimumSize: _tall,
                  backgroundColor: context.palette.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => SimpleHomeHelpSheet.show(context),
                icon: const Icon(Icons.sos),
                label: Text(l10n.simpleHomeHelp),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StartRideButton extends ConsumerWidget {
  final BikeEntity bike;
  const _StartRideButton({required this.bike});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(rideRecordingProvider.select((s) => s.status));
    final running =
        status == RecordingStatus.active || status == RecordingStatus.paused;
    return FilledButton.icon(
      key: const Key('simple_home_start_ride'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        textStyle: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      // Same flow as the Record tab's button (record_screen.dart).
      onPressed: status == RecordingStatus.starting
          ? null
          : () async {
              if (running) {
                context.go('/ride/active');
                return;
              }
              await ref
                  .read(rideRecordingProvider.notifier)
                  .startRide(bikeId: bike.id);
              if (!context.mounted) return;
              final result = ref.read(rideRecordingProvider);
              if (result.status == RecordingStatus.active) {
                context.go('/ride/active');
              } else {
                showRecordingBlockedSnackBar(context, result);
              }
            },
      icon: Icon(running ? Icons.navigation : Icons.play_arrow, size: 32),
      label: Text(running ? l10n.simpleHomeOpenRide : l10n.simpleHomeStartRide,
          textAlign: TextAlign.center),
    );
  }
}

class _Tile extends StatelessWidget {
  final String value;
  final String label;
  const _Tile({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return EditorialCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: t.bodyMedium),
        ],
      ),
    );
  }
}

class _MileageLine extends StatelessWidget {
  final MileageReading reading;
  const _MileageLine({required this.reading});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String n(double v) => v.toStringAsFixed(v >= 10 ? 0 : 1);
    final last = reading.lastKmPerLiter;
    final avg = reading.avgKmPerLiter;
    final (text, color) = switch (reading.verdict) {
      MileageVerdict.notEnoughData => (l10n.simpleHomeMileageNotEnough, null),
      MileageVerdict.firstOnly => (l10n.simpleHomeMileageFirst(n(last!)), null),
      MileageVerdict.good => (
          l10n.simpleHomeMileageGood(n(last!)),
          context.palette.success
        ),
      MileageVerdict.okay => (l10n.simpleHomeMileageOkay(n(last!)), null),
      MileageVerdict.low => (
          l10n.simpleHomeMileageLow(n(last!)),
          context.palette.attention
        ),
    };
    return Column(
      key: const Key('simple_home_mileage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        if (reading.verdict case MileageVerdict.okay || MileageVerdict.low)
          Text(l10n.simpleHomeMileageAverage(n(avg!))),
      ],
    );
  }
}
