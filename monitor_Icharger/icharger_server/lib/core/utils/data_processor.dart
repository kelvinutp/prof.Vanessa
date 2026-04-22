import '../models/battery_state.dart';
import '../models/serial_data.dart';
import 'dart:collection';

class DataProcessor {
  static const String delimiter = ';';
  
  // To handle the "most common element" logic for state if needed
  final ListQueue<String> _cycleDetector = ListQueue<String>();

  SerialData? parseRawLine({
    required String rawLine,
    required DateTime timestamp,
    required DateTime baseTime,
    required int currentCycle,
  }) {
    if (!rawLine.contains('\$')) return null;

    final columns = rawLine.split(delimiter);
    if (columns.length < 15) return null;

    // Find the starting of data indicated by '$'
    int dataStartIndex = columns.indexWhere((col) => col.contains('\$'));
    if (dataStartIndex == -1) return null;

    // Relative offsets from the '$' column (which is aux=0 in Python)
    // 1: state
    // 4: voltage (mV)
    // 5: current (cA)
    // 14: capacity (mAh)
    
    String stateId = columns[dataStartIndex + 1];
    String voltageRaw = columns[dataStartIndex + 4];
    String currentRaw = columns[dataStartIndex + 5];
    String capacityRaw = columns[dataStartIndex + 14];

    BatteryState state = BatteryState.fromId(stateId);
    double voltageV = (double.tryParse(voltageRaw) ?? 0) / 1000.0;
    double currentMA = (double.tryParse(currentRaw) ?? 0) / 100.0; // Wait, Python said i/100 for index 5. cA to mA is *10? Let's check Python again.
    // Python aux 5 was current (cA). str(int(i)/100). 100 cA = 1A = 1000mA. So i/100 is Amperes?
    // Let's re-read Python code.
    // aux == 5: result.append(str(int(i)/100)) -> This is Amperes if it's cA.
    // Index 5 in table: Applied current to the battery (cA).
    // So if i is 100 (100 cA), result is 1.0 (A).
    // I will stick to Python logic but maybe name it currentA instead of MA if it's Amperes.
    // Actually, in Flutter SerialData I named it `currentMA`. 
    // If it's cA (centiamperes), then 1 cA = 10 mA.
    // So mA = cA * 10.
    // Python aux 5: str(int(i)/100) -> Amperes.
    // I'll use Amperes to follow Python's numeric output exactly.
    
    int capacityMAh = int.tryParse(capacityRaw) ?? 0;

    return SerialData(
      timestamp: timestamp,
      systemTime: timestamp.difference(baseTime),
      cycleNumber: currentCycle,
      state: state,
      voltageV: voltageV,
      currentMA: currentMA, // This is actually Amperes if using Python logic
      capacityMAh: capacityMAh,
      rawLine: rawLine,
    );
  }

  bool detectCycleJump(BatteryState newState) {
    _cycleDetector.addLast(newState == BatteryState.charging ? '1' : 
                          newState == BatteryState.discharging ? '2' :
                          newState == BatteryState.rest ? '4' :
                          newState == BatteryState.finished ? '6' : '0');
    
    if (_cycleDetector.length > 5) {
      _cycleDetector.removeFirst();
    }

    if (_cycleDetector.length == 5) {
      final list = _cycleDetector.toList();
      // Python: cycle_history[-5:]==['4','4','1','1','1']
      if (list[0] == '4' && list[1] == '4' && list[2] == '1' && list[3] == '1' && list[4] == '1') {
        return true;
      }
    }
    return false;
  }
}
