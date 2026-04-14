import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/battery_session.dart';
import '../core/models/serial_data.dart';
import '../core/services/mqtt_client_service.dart';

class ClientProvider extends ChangeNotifier {
  MqttClientService? _mqttService;
  final Map<String, BatterySession> _sessions = {};
  bool _isConnected = false;
  String? _lastServerCode;
  String? _serverOfflineMessage;
  String? _welcomeMessage;
  final List<Map<String, dynamic>> mqttLogs = [];

  List<BatterySession> get sessions => _sessions.values.toList();
  bool get isConnected => _isConnected;
  String? get lastServerCode => _lastServerCode;
  String? get serverOfflineMessage => _serverOfflineMessage;
  String? get welcomeMessage => _welcomeMessage;

  ClientProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _lastServerCode = prefs.getString('last_server_code');
    notifyListeners();
  }

  Future<void> _saveSettings(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_server_code', code);
    _lastServerCode = code;
  }

  void connect(String serverCode) async {
    _serverOfflineMessage = null;
    _welcomeMessage = null;
    _mqttService = MqttClientService(
      onMessageReceived: _handleMqttMessage,
      onDisconnected: () {
        _isConnected = false;
        notifyListeners();
      },
    );

    _mqttService!.onLogMessage = (msg, {required isSent}) {
      mqttLogs.add({
        'text': msg,
        'isSent': isSent,
        'timestamp': DateTime.now()
      });
      notifyListeners();
    };

    final success = await _mqttService!.connect(serverCode);
    if (success) {
      _isConnected = true;
      _saveSettings(serverCode);
    }
    notifyListeners();
  }

  void _handleMqttMessage(Map<String, dynamic> payload) {
    final type = payload['type'];
    final data = payload['data'];

    if (type == 'status') {
      if (payload['state'] == 'offline') {
        _serverOfflineMessage = payload['message'] ?? 'Server went offline.';
        notifyListeners();
      }
    } else if (type == 'welcome') {
      _welcomeMessage = payload['message'] ?? 'Welcome!';
      notifyListeners();
    } else if (type == 'session_update') {
      _handleSessionUpdate(data);
    } else if (type == 'data_point') {
      final sessionId = payload['sessionId'];
      final point = SerialData.fromJson(data);
      
      if (_sessions.containsKey(sessionId)) {
        _sessions[sessionId]!.dataHistory.add(point);
        _sessions[sessionId]!.currentState = point.state;
        notifyListeners();
      }
    }
  }

  void _handleSessionUpdate(Map<String, dynamic> data) {
    final id = data['id'];
    if (!_sessions.containsKey(id)) {
      _sessions[id] = BatterySession(
        id: id,
        batteryName: data['batteryName'],
        nominalCapacity: data['nominalCapacity'],
        startingCycle: 1,
        savePath: '',
        port: '',
        isActive: data['isActive'],
      );
    } else {
      _sessions[id]!.isActive = data['isActive'];
    }
    notifyListeners();
  }

  void disconnect() {
    _mqttService?.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  void clearWelcomeMessage() {
    _welcomeMessage = null;
    notifyListeners();
  }

  void sendTestMessage() {
    _mqttService?.publishTestMessage();
  }
}
