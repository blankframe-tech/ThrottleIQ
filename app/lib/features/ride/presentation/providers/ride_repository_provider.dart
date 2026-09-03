import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ride_repository_impl.dart';
import '../../domain/repositories/ride_repository.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepositoryImpl();
});
