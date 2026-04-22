import 'package:flutter/foundation.dart';
import '../core/models/battery_session.dart';
import '../core/services/serial_monitor_service.dart';
import '../core/services/file_logging_service.dart';
import '../core/services/mqtt_server_service.dart';
import '../core/services/logger_service.dart';

class SessionProvider extends ChangeNotifier {
  final List<BatterySession> _sessions = [];
  final SerialMonitorService _serialService = SerialMonitorService();
  final FileLoggingService _fileService = FileLoggingService();
  final MqttServerService _mqttService = MqttServerService();
  final List<Map<String, dynamic>> mqttLogs = [];

  List<BatterySession> get sessions => _sessions;
  SerialMonitorService get serialService => _serialService;

  MqttServerService get mqttService => _mqttService;

  SessionProvider() {
    // Hook into LoggerService to show system logs in the UI
    logger.onLog = (msg) {
      mqttLogs.add({
        'text': msg,
        'isSent': false,
        'isSystem': true,
        'timestamp': DateTime.now()
      });
      notifyListeners();
    };

    _mqttService.onLogMessage = (msg, {required isSent}) {
      mqttLogs.add({
        'text': msg,
        'isSent': isSent,
        'isSystem': false,
        'timestamp': DateTime.now()
      });
      notifyListeners();
    };

    logger.log('Server: Initializing connection...');
    _mqttService.connect();
  }

  Future<int?> detectBaudRate(String portName, Function(String) onLog) async {
    logger.log('Server: detectBaudRate called for $portName');
    return _serialService.detectBaudRate(portName, onLog);
  }

  Future<void> addSession(BatterySession session) async {
    logger.log('Server: addSession called for ${session.batteryName}');
    await _fileService.initializeSessionFiles(session);
    _sessions.add(session);
    notifyListeners();
    
    _serialService.startMonitoring(
      session,
      (data) async {
        session.dataHistory.add(data);
        await _fileService.logData(session, data);
        _mqttService.broadcastSessionUpdate(session);
        _mqttService.broadcastDataPoint(session.id, data.toJson());
        notifyListeners();
      },
      (msg) {
        session.logs.add(msg);
        notifyListeners();
      },
    );
  }

  void stopSession(String id) {
    logger.log('Server: stopSession called for $id');
    _serialService.stopMonitoring(id);
    final session = _sessions.firstWhere((s) => s.id == id);
    session.isActive = false;
    _mqttService.broadcastSessionUpdate(session);
    notifyListeners();
  }

  void sendTestMessage() {
    logger.log('Server: sendTestMessage called');
    _mqttService.broadcastTestMessage();
  }

  Future<String> getDefaultPath() => _fileService.getDefaultSavePath();

  @override
  void dispose() {
    logger.log('Server: dispose() called');
    _serialService.dispose();
    _mqttService.dispose();
    super.dispose();
  }
}

