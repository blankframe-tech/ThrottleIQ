import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/utils/rider_stats.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../ride/data/models/ride_model.dart';

final riderStatsProvider = FutureProvider<RiderStatsSummary>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  final bikes = ref.watch(garageProvider).valueOrNull ?? [];
  if (uid == null) return RiderStatsSummary.empty;

  final rows = await RideDao().getAllForUser(uid);
  final rides = rows.map(RideModel.fromMap).toList();
  return computeRiderStats(rides: rides, bikes: bikes);
});
