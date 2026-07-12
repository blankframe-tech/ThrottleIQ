import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  static final Battery _battery = Battery();

  static Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      // Fallback if battery_plus not available
      return 100;
    }
  }

  static Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      return BatteryState.unknown;
    }
  }
}
