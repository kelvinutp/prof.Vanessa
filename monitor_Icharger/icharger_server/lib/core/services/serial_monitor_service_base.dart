import 'dart:async';
import '../models/battery_session.dart';
import '../models/serial_data.dart';

abstract class SerialMonitorService {
  Stream<SerialData> get dataStream;
  List<String> listAvailablePorts();
  bool isPortBusy(String portName);
  Future<int?> detectBaudRate(String portName, Function(String) onLog);
  void startMonitoring(BatterySession session, Function(SerialData) onData, Function(String) onLog);
  void stopMonitoring(String sessionId);
  void dispose();

  factory SerialMonitorService() => throw UnsupportedError('Use conditional imports');
}
