import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/ride_route_map.dart';
import '../providers/ride_polyline_provider.dart';

/// A ride's recorded route, small, for a list row.
///
/// Renders **nothing at all** when the ride has no recorded points — most
/// commonly a ride recorded before GPS locked on, or a crash-terminated one.
/// A row with no route should look like a row with no route, not like a
/// broken map, so the empty placeholder [RideRouteMap] draws on its own is
/// suppressed here and the row simply stays compact.
class RideRouteThumbnail extends ConsumerWidget {
  final String rideId;
  final double height;

  const RideRouteThumbnail({
    super.key,
    required this.rideId,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polyline = ref.watch(ridePolylineProvider(rideId));

    return polyline.when(
      loading: () => _placeholder(),
      // A failed point read is not worth shouting about in a list row — the
      // ride's own numbers are still right there.
      error: (_, __) => const SizedBox.shrink(),
      data: (points) {
        if (points.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: RideRouteMap(polyline: points, height: height),
        );
      },
    );
  }

  Widget _placeholder() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
        ),
      );
}
