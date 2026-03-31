import 'dart:async';
import 'dart:io';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/battery_state.dart';

class SerialParser {
  static List<String> extractColumns(String data, List<String> dataHistory) {
    var columns = data.split(';');
    List<String> result = [];
    String? estado;
    int aux = 0;
    bool aux2 = false;

    for (var col in columns) {
      if (col.contains('\$')) aux2 = true;
      if (aux2) {
        if ([1, 4, 5, 14].contains(aux)) {
          if (aux == 1) {
            String stateStr = col.trim();
            if (dataHistory.isNotEmpty) {
              var freq = <String, int>{};
              for (var h in dataHistory) freq[h] = (freq[h] ?? 0) + 1;
              var mostCommon = freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
              if (mostCommon != stateStr) stateStr = mostCommon;
            }
            if (stateStr == '1') estado = 'charging';
            else if (stateStr == '2') estado = 'discharging';
            else if (stateStr == '4') estado = 'rest';
            else if (stateStr == '6') estado = 'finished';
            result.add(estado ?? stateStr);
          } else if (aux == 4) {
            result.add(((int.tryParse(col) ?? 0) / 1000).toString());
          } else if (aux == 5) {
            result.add(((int.tryParse(col) ?? 0) / 100).toString());
          } else {
            result.add(col);
          }
        }
        aux++;
      } else {
        result.add(col);
      }
    }
    return [result.join(';'), estado ?? 'unknown'];
  }
}

class SerialService {
  static final Map<String, SerialPortReader> _readers = {};
  static final Map<String, SerialPort> _ports = {};

  // Per-battery terminal log (last 200 lines)
  static final Map<String, List<String>> terminalLogs = {};

  /// Returns list of ports with availability label: "COM3", "COM3 (Busy)"
  static List<Map<String, dynamic>> getAvailablePortsWithStatus() {
    final available = SerialPort.availablePorts;
    final busyPorts = _ports.values.map((p) => p.name).toSet();
    return available.map((p) {
      final isBusy = busyPorts.contains(p);
      return {'port': p, 'busy': isBusy, 'label': isBusy ? '$p (Busy)' : p};
    }).toList();
  }

  static List<String> getAvailablePorts() => SerialPort.availablePorts;

  static bool isPortBusy(String port) => _ports.containsKey(port) || 
      _ports.values.any((sp) => sp.name == port);

  static List<String> getTerminalLogs(String batteryId) =>
      List.unmodifiable(terminalLogs[batteryId] ?? []);

  static void _appendLog(String batteryId, String line) {
    terminalLogs.putIfAbsent(batteryId, () => []);
    final logs = terminalLogs[batteryId]!;
    logs.add(line);
    if (logs.length > 200) logs.removeAt(0);
  }

  static Future<void> startMonitoring(BatteryInfo info, Function(BatteryInfo) onUpdate) async {
    final port = SerialPort(info.port);
    const baudRates = [9600, 19200, 38400, 57600, 115200, 230400];
    int? detectedBaud;

    info.status = 'auto-detecting baud...';
    onUpdate(info);
    terminalLogs[info.batteryId] = [];
    _appendLog(info.batteryId, '[${_now()}] Probing baud rates on ${info.port}...');

    for (var rate in baudRates) {
      if (port.isOpen) port.close();
      if (!port.openReadWrite()) continue;
      port.config.baudRate = rate;
      
      try {
        final data = port.read(1024, timeout: 1500);
        String s = String.fromCharCodes(data);
        if (s.contains('\$') && s.contains(';')) {
          detectedBaud = rate;
          break;
        }
      } catch (_) {}
    }

    if (detectedBaud == null) {
      if (port.isOpen) port.close();
      info.status = 'error';
      info.errorMsg = 'Could not detect valid data at any baud rate.';
      _appendLog(info.batteryId, '[${_now()}] ERROR: Auto-baud detection failed. No valid iCharger data found.');
      onUpdate(info);
      return;
    }

    info.baudrate = detectedBaud;
    _ports[info.batteryId] = port;

    final reader = SerialPortReader(port);
    _readers[info.batteryId] = reader;

    info.status = 'monitoring';
    onUpdate(info);

    _appendLog(info.batteryId, '[${_now()}] Locked on ${info.port} @ ${info.baudrate} baud');

    DateTime baseTime = DateTime.now();
    int manipulableCycle = int.tryParse(info.ciclo) ?? 1;
    List<String> cycleHistory = [];

    // Create folder & raw file
    String folderStr = info.folder.isEmpty ? '.' : info.folder;
    Directory dir = Directory(folderStr);
    if (!await dir.exists()) await dir.create(recursive: true);

    File rawFile = File('$folderStr/data_original_${info.bateria}_${info.capacidad}_$manipulableCycle.csv');
    if (!await rawFile.exists()) {
      await rawFile.writeAsString(
          'date;system_time;cycle_time;cycle_number;data starting;cycle;empty;'
          'provided voltage;voltage (mV);current (cA);battery1;battery2;'
          'battery3;battery4;battery5;battery6;unknown0;unknown1;capacity (mAh);unknown2\n');
    }

    String buffer = '';
    reader.stream.listen((data) async {
      buffer += String.fromCharCodes(data);
      if (!buffer.contains('\n')) return;

      List<String> lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        final now = DateTime.now();
        final ts = _timestamp(now);
        final diff = now.difference(baseTime);

        var partsStr = line.split(';');
        if (partsStr.length > 1) cycleHistory.add(partsStr[1]);

        String output = '$ts;${diff.inSeconds};$manipulableCycle;$line';
        _appendLog(info.batteryId, output);

        await rawFile.writeAsString('$output\n', mode: FileMode.append);

        List<String> historySlice = cycleHistory.length > 5
            ? cycleHistory.sublist(cycleHistory.length - 5)
            : List.from(cycleHistory);

        var extracted = SerialParser.extractColumns(output, historySlice);
        String modifiedData = extracted[0];
        String currentState = extracted[1];

        if (historySlice.length == 5) {
          if (historySlice.join(',') == '4,4,1,1,1') {
            manipulableCycle++;
            baseTime = DateTime.now();
            _appendLog(info.batteryId, '[${_now()}] >>> Cycle incremented to $manipulableCycle');
          } else if (historySlice.join(',') == '6,6,6,6,6') {
            stopMonitoring(info.batteryId);
            info.status = 'finished';
            info.state = 'finished';
            _appendLog(info.batteryId, '[${_now()}] *** Monitoring FINISHED ***');
            onUpdate(info);
            return;
          }
        }

        var finalParts = modifiedData.split(';');
        info.state = currentState;
        info.voltage = finalParts.length > 5 ? finalParts[5] : '0';
        info.current = finalParts.length > 6 ? finalParts[6] : '0';
        info.capacity = finalParts.length > 7 ? finalParts[7] : '0';
        info.lastUpdate = ts;
        onUpdate(info);

        // Write state file
        File stateFile = File('$folderStr/${info.bateria}${currentState}_${info.capacidad}_$manipulableCycle.csv');
        if (!await stateFile.exists()) {
          await stateFile.writeAsString(
              'date;system_time;cycle_time;cycle_number;battery_state;voltage[V];current[mA];capacity[mAh]\n');
        }
        await stateFile.writeAsString('$modifiedData\n', mode: FileMode.append);
      }
    });
  }

  static void stopMonitoring(String batteryId) {
    _readers[batteryId]?.close();
    _readers.remove(batteryId);
    _ports[batteryId]?.close();
    _ports.remove(batteryId);
    _appendLog(batteryId, '[${_now()}] Monitoring stopped by user.');
  }

  static String _now() {
    final n = DateTime.now();
    return _timestamp(n);
  }

  static String _timestamp(DateTime n) {
    return '${n.year}-${_p(n.month)}-${_p(n.day)};${_p(n.hour)}:${_p(n.minute)}:${_p(n.second)}';
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}
