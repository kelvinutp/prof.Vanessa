import 'battery_state.dart';
import 'serial_data.dart';

class BatterySession {
  final String id;
  final String batteryName;
  int nominalCapacity;
  final int startingCycle;
  final String savePath;
  final String port;
  int baudRate;
  
  BatteryState currentState;
  int currentCycle;
  List<SerialData> dataHistory;
  List<String> logs;
  bool isActive;
  String? errorMessage;

  BatterySession({
    required this.id,
    required this.batteryName,
    required this.nominalCapacity,
    required this.startingCycle,
    required this.savePath,
    required this.port,
    this.baudRate = 9600,
    this.currentState = BatteryState.unknown,
    this.isActive = false,
  })  : currentCycle = startingCycle,
        dataHistory = [],
        logs = [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'batteryName': batteryName,
        'nominalCapacity': nominalCapacity,
        'currentCycle': currentCycle,
        'currentState': currentState.index,
        'isActive': isActive,
        'lastData': dataHistory.isNotEmpty ? dataHistory.last.toJson() : null,
      };
}
