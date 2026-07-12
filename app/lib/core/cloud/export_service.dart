import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../database/daos/ride_point_dao.dart';
import '../database/database_helper.dart';

/// Service for exporting ride data to various formats
class ExportService {
  final RidePointDao _ridePointDao = RidePointDao(DatabaseHelper.instance);

  /// Export ride data to JSON file
  Future<File?> exportRideToJSON(Map<String, dynamic> ride) async {
    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) return null;

      final rideId = ride['id'] as String;
      final fileName = 'ride_${rideId}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      // Fetch ride points
      final points = await _ridePointDao.getByRideId(rideId);

      final jsonData = {
        'ride': ride,
        'points': points,
        'exportedAt': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(jsonData), flush: true);
      return file;
    } catch (e) {
      print('Error exporting to JSON: $e');
      return null;
    }
  }

  /// Export ride polyline to GPX file
  Future<File?> exportRideToGPX(Map<String, dynamic> ride) async {
    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) return null;

      final rideId = ride['id'] as String;
      final fileName = 'ride_${rideId}_${DateTime.now().millisecondsSinceEpoch}.gpx';
      final file = File('${directory.path}/$fileName');

      // Fetch ride points
      final points = await _ridePointDao.getByRideId(rideId);

      final gpxContent = _generateGPX(ride, points);
      await file.writeAsString(gpxContent, flush: true);
      return file;
    } catch (e) {
      print('Error exporting to GPX: $e');
      return null;
    }
  }

  /// Generate GPX XML string from ride data
  String _generateGPX(Map<String, dynamic> ride, List<Map<String, dynamic>> ridePoints) {
    final startTime = ride['startTime'] as String;
    final distanceKm = (ride['distanceM'] as num) / 1000;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="ThrottleIQ" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>Motorcycle Ride</name>');
    buffer.writeln('    <time>$startTime</time>');

    if (ridePoints.isNotEmpty) {
      final lats = ridePoints.map<double>((p) => p['lat'] as double).toList();
      final lngs = ridePoints.map<double>((p) => p['lng'] as double).toList();

      final minLat = lats.reduce((a, b) => a < b ? a : b);
      final maxLat = lats.reduce((a, b) => a > b ? a : b);
      final minLng = lngs.reduce((a, b) => a < b ? a : b);
      final maxLng = lngs.reduce((a, b) => a > b ? a : b);

      buffer.writeln('    <bounds minlat="$minLat" minlon="$minLng" maxlat="$maxLat" maxlon="$maxLng" />');
    }

    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>Motorcycle Ride</name>');
    buffer.writeln('    <desc>Distance: ${distanceKm.toStringAsFixed(2)} km</desc>');
    buffer.writeln('    <extensions>');
    buffer.writeln('      <gpxtpx:TrackPointExtension>');
    buffer.writeln(
        '        <gpxtpx:atemp>${(ride['avgSpeedMs'] != null ? (ride['avgSpeedMs'] as num) * 3.6 : 0).toStringAsFixed(2)}</gpxtpx:atemp>');
    buffer.writeln('      </gpxtpx:TrackPointExtension>');
    buffer.writeln('    </extensions>');
    buffer.writeln('    <trkseg>');

    for (final point in ridePoints) {
      final lat = point['lat'] as num;
      final lng = point['lng'] as num;
      final timestamp = point['timestamp'] as String;
      final elevation = point['altitudeM'] as num?;

      buffer.write('      <trkpt lat="$lat" lon="$lng">');
      if (elevation != null && elevation != 0) {
        buffer.write('<ele>${elevation.toStringAsFixed(2)}</ele>');
      }
      buffer.writeln('<time>$timestamp</time></trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Get downloads directory path for display
  Future<String?> getDownloadsPath() async {
    final directory = await getDownloadsDirectory();
    return directory?.path;
  }
}

/// Riverpod provider for export service
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
