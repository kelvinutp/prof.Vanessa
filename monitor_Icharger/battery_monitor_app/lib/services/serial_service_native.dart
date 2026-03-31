import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/battery_state.dart';

class SerialParser {
  static List<String> extractColumns(String data, List<String> dataHistory) {
    var columns = data.split(';');
    List<String> result = [];
    String? estado;
    int aux = 0;
    bool aux2 = false;

    for (var i in columns) {
      if (i.contains('\$')) {
        aux2 = true;
      }

      if (aux2) {
        if ([1, 4, 5, 14].contains(aux)) {
          if (aux == 1) {
            String stateStr = i.trim();
            if (dataHistory.isNotEmpty) {
              var map = <String, int>{};
              for (var h in dataHistory) {
                map[h] = (map[h] ?? 0) + 1;
              }
              var mostCommon = map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
              if (mostCommon != stateStr) {
                stateStr = mostCommon;
              }
            }
            if (stateStr == '1') estado = 'charging';
            else if (stateStr == '2') estado = 'discharging';
            else if (stateStr == '4') estado = 'rest';
            else if (stateStr == '6') estado = 'finished';

            result.add(estado ?? stateStr);
          } else if (aux == 4) {
            int val = int.tryParse(i) ?? 0;
            result.add((val / 1000).toString());
          } else if (aux == 5) {
            int val = int.tryParse(i) ?? 0;
            result.add((val / 100).toString());
          } else {
            result.add(i);
          }
        }
        aux++;
      } else {
        result.add(i);
      }
    }
    return [result.join(';'), estado ?? 'unknown'];
  }
}

class SerialService {
  static final Map<String, SerialPortReader> _readers = {};
  static final Map<String, SerialPort> _ports = {};

  static List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  static Future<void> startMonitoring(BatteryInfo info, Function(BatteryInfo) onUpdate) async {
    final port = SerialPort(info.port);
    if (!port.openReadWrite()) {
      info.status = 'error';
      info.errorMsg = "Unable to open port";
      onUpdate(info);
      return;
    }
    
    port.config.baudRate = info.baudrate;
    _ports[info.batteryId] = port;

    final reader = SerialPortReader(port);
    _readers[info.batteryId] = reader;
    
    info.status = 'monitoring';
    onUpdate(info);

    DateTime baseTime = DateTime.now();
    int manipulableCycle = int.tryParse(info.ciclo) ?? 1;
    List<String> cycleHistory = [];

    // Open file handles
    String folderStr = info.folder.isEmpty ? "." : info.folder;
    Directory dir = Directory(folderStr);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    File rawFile = File('$folderStr/data_original_${info.bateria}_${info.capacidad}_$manipulableCycle.csv');
    if (!await rawFile.exists()) {
      await rawFile.writeAsString('date;system_time;cycle_time;cycle_number;data starting;cycle;empty;provided voltage;voltage (mV);current (cA);battery1;battery2;battery3;battery4;battery5;battery6;unknown0;unknown1;capacity (mAh);unknown2\n');
    }

    String buffer = "";
    
    reader.stream.listen((data) async {
      buffer += String.fromCharCodes(data);
      if (buffer.contains('\n')) {
        List<String> lines = buffer.split('\n');
        buffer = lines.removeLast(); // Keep the incomplete line in buffer

        for (String line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;
          
          String timestamp = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')};${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}:${DateTime.now().second.toString().padLeft(2,'0')}";
          Duration diff = DateTime.now().difference(baseTime);
          
          var partsStr = line.split(';');
          if(partsStr.length > 1) {
            cycleHistory.add(partsStr[1]);
          }

          String output = "$timestamp;${diff.inSeconds};$manipulableCycle;$line";
          
          // Write raw
          await rawFile.writeAsString('$output\n', mode: FileMode.append);

          // Extract columns
          List<String> historySlice = cycleHistory.length > 5 ? cycleHistory.sublist(cycleHistory.length - 5) : cycleHistory;
          var extracted = SerialParser.extractColumns(output, historySlice);
          String modifiedData = extracted[0];
          String currentState = extracted[1];

          // Check if finished or transition
          bool allRestOrCharge = false;
          if (historySlice.length == 5) {
             if (historySlice.join(',') == '4,4,1,1,1') {
               manipulableCycle++;
               baseTime = DateTime.now();
             } else if (historySlice.join(',') == '6,6,6,6,6') {
               stopMonitoring(info.batteryId);
               info.status = 'finished';
               info.state = 'finished';
               onUpdate(info);
               return;
             }
          }

          var finalParts = modifiedData.split(';');
          
          info.state = currentState;
          info.voltage = finalParts.length > 5 ? finalParts[5] : "0";
          info.current = finalParts.length > 6 ? finalParts[6] : "0";
          info.capacity = finalParts.length > 7 ? finalParts[7] : "0";
          info.lastUpdate = timestamp;
          
          onUpdate(info);
          
          // Write specific state file
          File stateFile = File('$folderStr/${info.bateria}${currentState}_${info.capacidad}_$manipulableCycle.csv');
          if (!await stateFile.exists()) {
             await stateFile.writeAsString('date;system_time;cycle_time;cycle_number;battery_state;voltage[V];current[mA];capacity[mAh]\n');
          }
          await stateFile.writeAsString('$modifiedData\n', mode: FileMode.append);

        }
      }
    });
  }

  static void stopMonitoring(String batteryId) {
    if (_readers.containsKey(batteryId)) {
      _readers[batteryId]!.close();
      _readers.remove(batteryId);
    }
    if (_ports.containsKey(batteryId)) {
      _ports[batteryId]!.close();
      _ports.remove(batteryId);
    }
  }
}
