import 'dart:async';
import 'dart:convert';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/battery_session.dart';
import '../models/serial_data.dart';
import '../utils/data_processor.dart';

class SerialMonitorService {
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final _dataStreamController = StreamController<SerialData>.broadcast();

  Stream<SerialData> get dataStream => _dataStreamController.stream;

  List<String> listAvailablePorts() {
    return SerialPort.availablePorts;
  }

  bool isPortBusy(String portName) {
    try {
      final port = SerialPort(portName);
      final isOpen = port.openReadWrite();
      if (isOpen) {
        port.close();
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  void startMonitoring(BatterySession session, Function(SerialData) onData) {
    if (_activeSubscriptions.containsKey(session.id)) return;

    final port = SerialPort(session.port);
    final processor = DataProcessor();
    DateTime baseTime = DateTime.now();

    try {
      if (!port.openReadWrite()) {
        session.errorMessage = "Could not open port ${session.port}";
        return;
      }

      port.config.baudRate = session.baudRate;
      // You might need more config here like parity etc based on Python code (which used defaults)

      session.isActive = true;
      final reader = SerialPortReader(port);
      
      final sub = reader.stream.listen((data) {
        final rawLine = utf8.decode(data, allowMalformed: true).trim();
        if (rawLine.isEmpty) return;

        final parsed = processor.parseRawLine(
          rawLine: rawLine,
          timestamp: DateTime.now(),
          baseTime: baseTime,
          currentCycle: session.currentCycle,
        );

        if (parsed != null) {
          if (processor.detectCycleJump(parsed.state)) {
            session.currentCycle++;
            baseTime = DateTime.now();
          }
          session.currentState = parsed.state;
          onData(parsed);
          _dataStreamController.add(parsed);
        }
      });

      _activeSubscriptions[session.id] = sub;
    } catch (e) {
      session.errorMessage = e.toString();
      session.isActive = false;
    }
  }

  void stopMonitoring(String sessionId) {
    _activeSubscriptions[sessionId]?.cancel();
    _activeSubscriptions.remove(sessionId);
  }

  void dispose() {
    for (var sub in _activeSubscriptions.values) {
      sub.cancel();
    }
    _dataStreamController.close();
  }
}
