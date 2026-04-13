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

  Future<int?> detectBaudRate(String portName, Function(String) onLog) async {
    const commonBaudRates = [9600, 14400, 19200, 38400, 57600, 115200, 128000, 256000, 460800, 921600];

    for (int attempt = 1; attempt <= 2; attempt++) {
      onLog('[SYSTEM] Baud rate detection loop $attempt/2');
      for (final baudRate in commonBaudRates) {
        onLog('[SYSTEM] Testing baud rate $baudRate...');
        try {
          final port = SerialPort(portName);
          if (!port.openReadWrite()) {
            onLog('[SYSTEM] Failed to open port at $baudRate');
            continue;
          }
          port.config.baudRate = baudRate;
          
          final reader = SerialPortReader(port);
          final completer = Completer<int?>();
          final sub = reader.stream.listen((data) {
            final rawLine = utf8.decode(data, allowMalformed: true).trim();
            if (rawLine.contains('\$')) {
              if (!completer.isCompleted) {
                completer.complete(baudRate);
              }
            }
          });

          final result = await Future.any([
            completer.future,
            Future.delayed(const Duration(milliseconds: 500), () => null)
          ]);

          sub.cancel();
          port.close();

          if (result != null) {
            onLog('[SYSTEM] Successfully detected baud rate: $baudRate');
            return baudRate;
          }
        } catch (e) {
          onLog('[SYSTEM] Error testing $baudRate: $e');
        }
      }
    }
    return null;
  }

  void startMonitoring(BatterySession session, Function(SerialData) onData, Function(String) onLog) {
    if (_activeSubscriptions.containsKey(session.id)) return;

    final port = SerialPort(session.port);
    final processor = DataProcessor();
    DateTime baseTime = DateTime.now();

    try {
      if (!port.openReadWrite()) {
        session.errorMessage = "Could not open port ${session.port}";
        onLog('[SYSTEM] Error: Could not open port ${session.port}');
        return;
      }

      port.config.baudRate = session.baudRate;
      onLog('[SYSTEM] Connecting to ${session.port} at ${session.baudRate} baud');

      session.isActive = true;
      final reader = SerialPortReader(port);
      
      final sub = reader.stream.listen((data) {
        final rawLine = utf8.decode(data, allowMalformed: true).trim();
        if (rawLine.isEmpty) return;

        // Add raw output to normal logs if desired, but here we can just log raw serial string
        session.logs.add(rawLine);

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
            onLog('[SYSTEM] Cycle jump detected. New cycle: ${session.currentCycle}');
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
      onLog('[SYSTEM] Exception starting monitor: $e');
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
