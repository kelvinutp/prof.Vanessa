import '../models/battery_state.dart';

class SerialService {
  static List<String> getAvailablePorts() => [];

  static void startMonitoring(BatteryInfo info, Function(BatteryInfo) onUpdate) {
    print("SerialPort is not supported on this platform.");
  }

  static void stopMonitoring(String batteryId) {}
}
