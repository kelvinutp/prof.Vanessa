import 'dart:async';
import '../models/battery_session.dart';
import '../models/serial_data.dart';

class SerialMonitorService {
  final _dataStreamController = StreamController<SerialData>.broadcast();

  Stream<SerialData> get dataStream => _dataStreamController.stream;

  List<String> listAvailablePorts() {
    return ['WEB_STUB_PORT_1', 'WEB_STUB_PORT_2'];
  }

  bool isPortBusy(String portName) {
    return false;
  }

  Future<int?> detectBaudRate(String portName, Function(String) onLog) async {
    onLog('[WEB] Serial access is not supported on web in this build.');
    return 9600;
  }

  void startMonitoring(BatterySession session, Function(SerialData) onData, Function(String) onLog) {
    onLog('[WEB] Monitoring started (stub). No real data will be received.');
    session.isActive = true;
  }

  void stopMonitoring(String sessionId) {
    // Stub
  }

  void dispose() {
    _dataStreamController.close();
  }
}
