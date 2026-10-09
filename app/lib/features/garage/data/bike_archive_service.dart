import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/daos/bike_dao.dart';
import '../../../core/database/daos/fuel_log_dao.dart';
import '../../../core/database/daos/maintenance_dao.dart';
import '../../../core/database/daos/ride_dao.dart';
import '../../social/data/repositories/ride_share_repository.dart';
import '../domain/entities/bike_entity.dart';

/// What the rider asked to remove along with an archived bike. All off by
/// default: archiving keeps everything.
class ArchiveCleanup {
  final bool sharedRides;
  final bool miles;
  final bool serviceLogs;
  final bool fuelLogs;
  final bool photos;

  const ArchiveCleanup({
    this.sharedRides = false,
    this.miles = false,
    this.serviceLogs = false,
    this.fuelLogs = false,
    this.photos = false,
  });

  bool get isEmpty =>
      !sharedRides && !miles && !serviceLogs && !fuelLogs && !photos;
}

/// Archiving a bike, exporting its data, and deleting it for good.
///
/// An archived bike is kept for [kArchiveRetention] and then deleted by
/// [purgeExpired], which runs on app start (Spark has no scheduled functions,
/// so a bike is only purged once the app is opened after its deadline).
class BikeArchiveService {
  BikeArchiveService({
    BikeDao? bikes,
    RideDao? rides,
    MaintenanceDao? maintenance,
    FuelLogDao? fuel,
    Future<int> Function(String uid, String bikeId)? deleteSharedRides,
  })  : _bikes = bikes ?? BikeDao(),
        _rides = rides ?? RideDao(),
        _maintenance = maintenance ?? MaintenanceDao(),
        _fuel = fuel ?? FuelLogDao(),
        _deleteSharedRides = deleteSharedRides ??
            ((uid, bikeId) =>
                RideShareRepository().deleteSharedRidesForBike(uid, bikeId));

  final BikeDao _bikes;
  final RideDao _rides;
  final MaintenanceDao _maintenance;
  final FuelLogDao _fuel;
  final Future<int> Function(String uid, String bikeId) _deleteSharedRides;

  /// Archives [bike], first removing whatever [cleanup] asks for. The shared
  /// rides live in Firestore, so they go first: if that fails nothing is
  /// archived and the rider can retry.
  Future<void> archive(BikeEntity bike, ArchiveCleanup cleanup) async {
    if (cleanup.sharedRides) {
      await _deleteSharedRides(bike.userId, bike.id);
    }
    await _bikes.setArchived(
      bike.id,
      true,
      deleteServiceLogs: cleanup.serviceLogs,
      deleteFuelLogs: cleanup.fuelLogs,
      deletePhotos: cleanup.photos,
      resetMiles: cleanup.miles,
    );
  }

  /// Permanently deletes [bike], its rides, logs and the cloud copies. Shared
  /// rides are removed best-effort: being offline must not stop the local
  /// delete, and the bike's tombstone still reaches the cloud later.
  Future<void> deleteNow(BikeEntity bike) async {
    try {
      await _deleteSharedRides(bike.userId, bike.id);
    } catch (e) {
      debugPrint('[bike-archive] shared rides not removed: $e');
    }
    await _bikes.delete(bike.id);
  }

  /// Deletes [userId]'s archived bikes whose retention has run out. Returns
  /// how many were deleted. Never throws: a failure is logged and the bike is
  /// tried again on the next start.
  Future<int> purgeExpired(String userId, {DateTime? now}) async {
    var purged = 0;
    try {
      final cutoff = (now ?? DateTime.now()).subtract(kArchiveRetention);
      final rows = await _bikes.getExpiredArchived(userId, cutoff);
      for (final row in rows) {
        try {
          try {
            await _deleteSharedRides(userId, row['id'] as String);
          } catch (e) {
            debugPrint('[bike-archive] shared rides not removed: $e');
          }
          await _bikes.delete(row['id'] as String);
          purged++;
        } catch (e) {
          debugPrint('[bike-archive] purge of ${row['id']} failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[bike-archive] purge failed: $e');
    }
    return purged;
  }

  /// The bike, its rides, its service logs and its fuel logs as JSON text.
  Future<String> exportJson(BikeEntity bike) async {
    final rides = await _rides.getAllForBike(bike.id);
    final logs = await _maintenance.getForBike(bike.id);
    final fuel = await _fuel.getForBike(bike.id);
    return const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'bike': {
        'id': bike.id,
        'brand': bike.brand,
        'model': bike.model,
        'year': bike.year,
        'cc': bike.cc,
        'odometerKm': bike.odometerKm,
        'totalDistanceM': bike.totalDistanceM,
        'rideCount': bike.rideCount,
        'archivedAt': bike.archivedAt?.toIso8601String(),
        'createdAt': bike.createdAt.toIso8601String(),
      },
      'rides': rides,
      'serviceLogs': logs,
      'fuelLogs': fuel,
    });
  }

  /// Writes the export to a file and opens the share sheet so the rider can
  /// save it to Files, Drive or send it to themselves.
  Future<void> shareExport(BikeEntity bike) async {
    final json = await exportJson(bike);
    final dir = await getTemporaryDirectory();
    final safeName = bike.displayName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final file = File('${dir.path}/throttleiq_$safeName.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
  }
}
