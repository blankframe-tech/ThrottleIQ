import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> medium() => HapticFeedback.mediumImpact();
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  static Future<void> alertPattern() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(pattern: [0, 200, 100, 200], intensities: [0, 255, 0, 255]);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> rideStart() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(duration: 300, amplitude: 200);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> rideStop() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(pattern: [0, 100, 80, 100, 80, 300]);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }
}
