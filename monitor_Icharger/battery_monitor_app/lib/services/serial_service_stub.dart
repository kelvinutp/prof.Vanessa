import '../models/battery_state.dart';

class SerialService {
  static List<Map<String, dynamic>> getAvailablePortsWithStatus() => [];
  static List<String> getAvailablePorts() => [];
  static Map<String, List<String>> get terminalLogs => {};
  static List<String> getTerminalLogs(String batteryId) => [];
  static bool isPortBusy(String port) => false;

  static void startMonitoring(BatteryInfo info, Function(BatteryInfo) onUpdate) {
    print('SerialPort not supported on this platform.');
  }

  static void stopMonitoring(String batteryId) {}
}
