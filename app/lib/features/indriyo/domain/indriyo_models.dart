import 'package:flutter/material.dart';

enum ThreatLevel {
  clear,
  monitoring,
  warning,  // Amber: Vehicle in Blind Spot
  critical, // Flashing Red: Collision Imminent (TTC < 1.8s)
}

enum ThreatZone {
  none,
  leftBlindSpot,
  rightBlindSpot,
  rearCenterCorridor,
}

class IndriyoVehicleDetection {
  final String id;
  final String className;
  final Rect boundingBox;
  final double distanceMeters;
  final double relativeSpeedKmh;
  final double ttcSeconds;
  final ThreatLevel threatLevel;
  final ThreatZone zone;

  const IndriyoVehicleDetection({
    required this.id,
    required this.className,
    required this.boundingBox,
    required this.distanceMeters,
    required this.relativeSpeedKmh,
    required this.ttcSeconds,
    required this.threatLevel,
    required this.zone,
  });
}

class IndriyoThreatState {
  final ThreatLevel highestThreat;
  final bool leftBlindSpotActive;
  final bool rightBlindSpotActive;
  final bool criticalCollision;
  final double minTtc;
  final List<IndriyoVehicleDetection> vehicles;
  final double fps;
  final double latencyMs;
  final bool isConnected;

  const IndriyoThreatState({
    this.highestThreat = ThreatLevel.clear,
    this.leftBlindSpotActive = false,
    this.rightBlindSpotActive = false,
    this.criticalCollision = false,
    this.minTtc = -1.0,
    this.vehicles = const [],
    this.fps = 0.0,
    this.latencyMs = 0.0,
    this.isConnected = false,
  });

  IndriyoThreatState copyWith({
    ThreatLevel? highestThreat,
    bool? leftBlindSpotActive,
    bool? rightBlindSpotActive,
    bool? criticalCollision,
    double? minTtc,
    List<IndriyoVehicleDetection>? vehicles,
    double? fps,
    double? latencyMs,
    bool? isConnected,
  }) {
    return IndriyoThreatState(
      highestThreat: highestThreat ?? this.highestThreat,
      leftBlindSpotActive: leftBlindSpotActive ?? this.leftBlindSpotActive,
      rightBlindSpotActive: rightBlindSpotActive ?? this.rightBlindSpotActive,
      criticalCollision: criticalCollision ?? this.criticalCollision,
      minTtc: minTtc ?? this.minTtc,
      vehicles: vehicles ?? this.vehicles,
      fps: fps ?? this.fps,
      latencyMs: latencyMs ?? this.latencyMs,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
