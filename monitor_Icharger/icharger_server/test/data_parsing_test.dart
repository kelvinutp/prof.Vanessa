import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icharger_server/core/utils/data_processor.dart';
import 'package:icharger_server/core/models/battery_state.dart';

void main() {
  test('Verify parsing logic with real sample data', () async {
    final file = File('../data_original_2_3800_1.csv');
    if (!await file.exists()) {
      debugPrint('Sample file not found at ${file.absolute.path}');
      return;
    }

    final lines = await file.readAsLines();
    final processor = DataProcessor();
    final baseTime = DateTime.now();
    int cycle = 1;

    // Skip header
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      
      final parsed = processor.parseRawLine(
        rawLine: lines[i],
        timestamp: DateTime.now(),
        baseTime: baseTime,
        currentCycle: cycle,
      );

      if (parsed != null) {
        expect(parsed.rawLine, equals(lines[i]));
        expect(parsed.state, isNot(BatteryState.unknown));
        
        if (processor.detectCycleJump(parsed.state)) {
          cycle++;
        }
      }
    }
    
    debugPrint('Successfully verified ${lines.length - 1} data rows');
    debugPrint('Detected total cycles: $cycle');
  });
}
