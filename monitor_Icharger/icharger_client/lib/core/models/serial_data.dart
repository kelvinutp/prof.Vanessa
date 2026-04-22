import 'battery_state.dart';

class SerialData {
  final DateTime timestamp;
  final Duration systemTime;
  final int cycleNumber;
  final BatteryState state;
  final double voltageV;
  final double currentMA;
  final int capacityMAh;
  final String rawLine;

  SerialData({
    required this.timestamp,
    required this.systemTime,
    required this.cycleNumber,
    required this.state,
    required this.voltageV,
    required this.currentMA,
    required this.capacityMAh,
    required this.rawLine,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'systemTime': systemTime.inMilliseconds,
        'cycleNumber': cycleNumber,
        'state': state.index,
        'voltageV': voltageV,
        'currentMA': currentMA,
        'capacityMAh': capacityMAh,
        'rawLine': rawLine,
      };

  factory SerialData.fromJson(Map<String, dynamic> json) => SerialData(
        timestamp: DateTime.parse(json['timestamp']),
        systemTime: Duration(milliseconds: json['systemTime']),
        cycleNumber: json['cycleNumber'],
        state: BatteryState.values[json['state'] as int],
        voltageV: json['voltageV'].toDouble(),
        currentMA: json['currentMA'].toDouble(),
        capacityMAh: json['capacityMAh'] as int,
        rawLine: json['rawLine'],
      );
      
  String toCsvRow(String delimiter) {
    return [
      timestamp.toString().split('.')[0], // Date
      systemTime.toString().split('.')[0], // System Time
      cycleNumber,
      state.displayName,
      voltageV.toStringAsFixed(3),
      currentMA.toStringAsFixed(2),
      capacityMAh,
    ].join(delimiter);
  }
}
