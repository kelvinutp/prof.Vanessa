import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/models/battery_session.dart';
import '../core/models/serial_data.dart';

class ClientProvider extends ChangeNotifier {
  WebSocketChannel? _channel;
  final Map<String, BatterySession> _sessions = {};
  bool _isConnected = false;

  List<BatterySession> get sessions => _sessions.values.toList();
  bool get isConnected => _isConnected;

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _isConnected = true;
    notifyListeners();

    _channel?.stream.listen(
      (message) {
        final payload = jsonDecode(message);
        final type = payload['type'];
        final data = payload['data'];

        if (type == 'session_update') {
          // Ideally map from Json, but I'll use a simplified mapping for now
          // In a production app, I'd implement BatterySession.fromJson
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
      },
      onError: (e) {
        _isConnected = false;
        notifyListeners();
      },
      onDone: () {
        _isConnected = false;
        notifyListeners();
      },
    );
  }

  void _handleSessionUpdate(Map<String, dynamic> data) {
    final id = data['id'];
    if (!_sessions.containsKey(id)) {
      _sessions[id] = BatterySession(
        id: id,
        batteryName: data['batteryName'],
        nominalCapacity: data['nominalCapacity'],
        startingCycle: 1, // Doesn't matter as much for client displays
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
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }
}
