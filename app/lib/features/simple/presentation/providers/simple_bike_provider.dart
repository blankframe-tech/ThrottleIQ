import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';

/// Simple mode's one bike: the active bike, else the first in the garage.
/// Null while the garage loads or when it is empty; screens check
/// [garageProvider]'s loading state first so the no-bike state doesn't flash.
final simpleBikeProvider = Provider<BikeEntity?>((ref) =>
    ref.watch(activeBikeProvider) ??
    ref.watch(garageProvider).valueOrNull?.firstOrNull);
