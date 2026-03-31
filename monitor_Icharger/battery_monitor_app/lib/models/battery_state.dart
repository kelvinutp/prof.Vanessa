class BatteryInfo {
  String batteryId;
  String port;
  int baudrate;
  String bateria;
  String capacidad;
  String ciclo;
  String folder;

  String status;
  String state;
  String voltage;
  String current;
  String capacity;
  String errorMsg;
  String lastUpdate;

  BatteryInfo({
    required this.batteryId,
    required this.port,
    required this.baudrate,
    required this.bateria,
    required this.capacidad,
    required this.ciclo,
    required this.folder,
    this.status = "starting",
    this.state = "unknown",
    this.voltage = "0",
    this.current = "0",
    this.capacity = "0",
    this.errorMsg = "",
    this.lastUpdate = "",
  });

  Map<String, dynamic> toJson() {
    return {
      'battery_id': batteryId,
      'port': port,
      'baudrate': baudrate,
      'bateria': bateria,
      'capacidad': capacidad,
      'ciclo': ciclo,
      'folder': folder,
      'status': status,
      'state': state,
      'voltage': voltage,
      'current': current,
      'capacity': capacity,
      'error_msg': errorMsg,
      'last_update': lastUpdate,
    };
  }

  factory BatteryInfo.fromJson(Map<String, dynamic> json) {
    return BatteryInfo(
      batteryId: json['battery_id'] ?? '',
      port: json['port'] ?? '',
      baudrate: json['baudrate'] ?? 9600,
      bateria: json['bateria'] ?? '',
      capacidad: json['capacidad'] ?? '',
      ciclo: json['ciclo'] ?? '',
      folder: json['folder'] ?? '',
      status: json['status'] ?? 'starting',
      state: json['state'] ?? 'unknown',
      voltage: json['voltage'] ?? '0',
      current: json['current'] ?? '0',
      capacity: json['capacity'] ?? '0',
      errorMsg: json['error_msg'] ?? '',
      lastUpdate: json['last_update'] ?? '',
    );
  }
}
