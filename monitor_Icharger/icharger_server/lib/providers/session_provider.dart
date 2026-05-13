import 'package:flutter/foundation.dart';
import '../core/models/battery_session.dart';
import '../core/services/serial_monitor_service.dart';
import '../core/services/file_logging_service.dart';
import '../core/services/mqtt_server_service.dart';
import '../core/services/unified_logger_service.dart';
import '../core/models/serial_data.dart';
import '../core/models/battery_state.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/models/chart_type.dart';

class SessionProvider extends ChangeNotifier {
  final List<BatterySession> _sessions = [];
  final SerialMonitorService _serialService = SerialMonitorService();
  final FileLoggingService _fileService = FileLoggingService();
  final MqttServerService _mqttService = MqttServerService();
  final List<Map<String, dynamic>> mqttLogs = [];

  // Analysis State
  final Map<String, List<SerialData>> analysisDataSources = {};
  final Set<int> selectedCycles = {};
  final Set<String> selectedSources = {'live'};
  final Set<BatteryState> selectedStages = {BatteryState.charging, BatteryState.discharging, BatteryState.rest};
  final Set<ChartType> visibleGraphs = {ChartType.voltage, ChartType.current, ChartType.capacity};
  
  double? zoomMinX;
  double? zoomMaxX;

  // Formatting State
  double timeScale = 1.0; 
  int voltagePrecision = 3;
  int currentPrecision = 2;

  void setTimeScale(double val) {
    timeScale = val;
    notifyListeners();
  }

  void setVoltagePrecision(int val) {
    voltagePrecision = val;
    notifyListeners();
  }

  void setCurrentPrecision(int val) {
    currentPrecision = val;
    notifyListeners();
  }

  List<BatterySession> get sessions => _sessions;
  SerialMonitorService get serialService => _serialService;

  MqttServerService get mqttService => _mqttService;

  SessionProvider() {
    _mqttService.onLogMessage = (msg, {required isSent}) {
      mqttLogs.add({
        'text': msg,
        'isSent': isSent,
        'isSystem': false,
        'timestamp': DateTime.now()
      });
      notifyListeners();
    };

    unifiedLogger.log('Server Provider: Initializing connection...', source: LogSource.system);
    _mqttService.connect();
  }

  Future<int?> detectBaudRate(String portName, Function(String) onLog) async {
    unifiedLogger.log('Server: detectBaudRate called for $portName', source: LogSource.serial);
    return _serialService.detectBaudRate(portName, (msg) {
      unifiedLogger.log('Baud Detection: $msg', source: LogSource.serial);
      onLog(msg);
    });
  }

  Future<void> addSession(BatterySession session) async {
    unifiedLogger.log('Server: addSession called for ${session.batteryName}', source: LogSource.system);
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
        unifiedLogger.log('Serial [${session.batteryName}]: $msg', source: LogSource.serial);
        notifyListeners();
      },
    );
  }

  void stopSession(String id) {
    unifiedLogger.log('Server: stopSession called for $id', source: LogSource.system);
    _serialService.stopMonitoring(id);
    final session = _sessions.firstWhere((s) => s.id == id);
    session.isActive = false;
    _mqttService.broadcastSessionUpdate(session);
    notifyListeners();
  }

  void sendTestMessage() {
    unifiedLogger.log('Server: sendTestMessage called', source: LogSource.mqtt);
    _mqttService.broadcastTestMessage();
  }

  Future<String> getDefaultPath() => _fileService.getDefaultSavePath();

  // Analysis Methods
  Future<void> importReferenceFile(String filePath) async {
    try {
      final file = File(filePath);
      final fileName = p.basename(filePath);
      final lines = await file.readAsLines();
      
      final List<SerialData> dataPoints = [];
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        
        final parts = line.split(';');
        if (parts.length < 8) continue;

        // Structure: date;system_time;cycle_time;cycle_number;battery_state;voltage[V];current[mA];capacity[mAh]
        final timestamp = DateTime.tryParse('${parts[0]} ${parts[1]}') ?? DateTime.now();
        final cycleTime = double.tryParse(parts[2]) ?? 0.0;
        final cycleNumber = int.tryParse(parts[3]) ?? 1;
        final state = BatteryState.fromId(parts[4]);
        final voltageV = double.tryParse(parts[5]) ?? 0.0;
        final currentMA = double.tryParse(parts[6]) ?? 0.0;
        final capacityMAh = int.tryParse(parts[7]) ?? 0;

        dataPoints.add(SerialData(
          timestamp: timestamp,
          systemTime: Duration(seconds: cycleTime.toInt()), // Approximate
          cycleTime: cycleTime,
          cycleNumber: cycleNumber,
          state: state,
          voltageV: voltageV,
          currentMA: currentMA,
          capacityMAh: capacityMAh,
          rawLine: line,
          sourceId: fileName,
        ));
      }

      analysisDataSources[fileName] = dataPoints;
      selectedSources.add(fileName);
      
      // Auto-add found cycles to selected if none selected
      final cyclesInFile = dataPoints.map((d) => d.cycleNumber).toSet();
      if (selectedCycles.isEmpty) {
        selectedCycles.addAll(cyclesInFile);
      }
      
      notifyListeners();
      unifiedLogger.log('Successfully imported $fileName with ${dataPoints.length} points', source: LogSource.ui);
    } catch (e) {
      unifiedLogger.log('Error importing CSV: $e', source: LogSource.ui);
      rethrow;
    }
  }

  void toggleCycle(int cycle) {
    if (selectedCycles.contains(cycle)) {
      selectedCycles.remove(cycle);
    } else {
      selectedCycles.add(cycle);
    }
    unifiedLogger.log('Toggled cycle $cycle: ${selectedCycles.contains(cycle)}', source: LogSource.ui);
    notifyListeners();
  }

  void toggleSource(String sourceId) {
    if (selectedSources.contains(sourceId)) {
      selectedSources.remove(sourceId);
    } else {
      selectedSources.add(sourceId);
    }
    unifiedLogger.log('Toggled source $sourceId: ${selectedSources.contains(sourceId)}', source: LogSource.ui);
    notifyListeners();
  }

  void toggleStage(BatteryState stage) {
    if (selectedStages.contains(stage)) {
      selectedStages.remove(stage);
    } else {
      selectedStages.add(stage);
    }
    unifiedLogger.log('Toggled stage filter: ${stage.displayName}', source: LogSource.ui);
    notifyListeners();
  }

  void toggleGraph(ChartType type) {
    if (visibleGraphs.contains(type)) {
      if (visibleGraphs.length > 1) { // Keep at least one graph
        visibleGraphs.remove(type);
      }
    } else {
      visibleGraphs.add(type);
    }
    unifiedLogger.log('Toggled graph visibility: $type', source: LogSource.ui);
    notifyListeners();
  }

  void setZoom(double minX, double maxX) {
    zoomMinX = minX;
    zoomMaxX = maxX;
    unifiedLogger.log('Set zoom range: ${minX.toStringAsFixed(1)}s - ${maxX.toStringAsFixed(1)}s', source: LogSource.ui);
    notifyListeners();
  }

  void resetZoom() {
    zoomMinX = null;
    zoomMaxX = null;
    unifiedLogger.log('Reset zoom range', source: LogSource.ui);
    notifyListeners();
  }

  void updateSessionMetadata(BatterySession session, {int? nominalCapacity, int? currentCycle}) {
    if (nominalCapacity != null) {
      final old = session.nominalCapacity;
      session.nominalCapacity = nominalCapacity;
      unifiedLogger.log('Updated capacity for ${session.batteryName}: $old -> $nominalCapacity', source: LogSource.ui);
    }
    if (currentCycle != null) {
      final old = session.currentCycle;
      session.currentCycle = currentCycle;
      unifiedLogger.log('Updated cycle for ${session.batteryName}: $old -> $currentCycle', source: LogSource.ui);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unifiedLogger.log('Server Provider: dispose() called', source: LogSource.system);
    _serialService.dispose();
    _mqttService.dispose();
    unifiedLogger.shutdown();
    super.dispose();
  }
}

