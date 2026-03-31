import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/serial_parser.dart';

void main() {
  test('Mock Test with data.csv', () async {
    final file = File('../test_data/data.csv'); // Relative from battery_monitor_app/
    if (!await file.exists()) {
      print('data.csv not found!');
      return;
    }

    final lines = await file.readAsLines();
    print('Testing ${lines.length} lines from data.csv...');

    List<String> cycleHistory = [];
    int success = 0;

    for (var line in lines) {
      if (line.isEmpty) continue;

      // The raw data from multiple_tabs looks like:
      // timestamp;diff;cycle;raw_data
      // We will mock this payload:
      String mockPayload = "2026-03-30;timestamp;1;$line";

      var partsStr = line.split(';');
      if (partsStr.length > 1) {
        cycleHistory.add(partsStr[1]);
      }

      List<String> historySlice = cycleHistory.length > 5 
          ? cycleHistory.sublist(cycleHistory.length - 5) 
          : cycleHistory;

      var extracted = SerialParser.extractColumns(mockPayload, historySlice);
      String resultString = extracted.split('|').first;
      String estado = extracted.split('|').last;

      if (estado.isNotEmpty) {
        success++;
      }
    }
    
    print('Successfully processed $success mock data events from data.csv');
    expect(success > 0, true);
  });
}
