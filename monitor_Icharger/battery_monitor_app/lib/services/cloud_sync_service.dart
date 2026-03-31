import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/battery_state.dart';

class CloudSyncService {
  static MqttServerClient? _client;
  static String cloudCode = '';
  static bool isConnected = false;
  static bool _isConnecting = false;
  static Timer? _reconnectTimer;
  static const Duration _reconnectInterval = Duration(seconds: 10);

  static final StreamController<Map<String, dynamic>> _dataStream =
      StreamController.broadcast();

  static Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;

  static void generateCloudCode() {
    final rng = Random.secure();
    cloudCode = (100000 + rng.nextInt(899999)).toString(); // 6 digits
  }

  static Future<void> connectDesktop() async {
    generateCloudCode();
    final success = await _connect();
    if (!success) {
      _startAutoReconnect();
    } else {
      _stopAutoReconnect();
    }
  }

  static Future<bool> connectMobile(String code) async {
    cloudCode = code;
    final success = await _connect();
    if (!success) {
      _startAutoReconnect();
    } else {
      _stopAutoReconnect();
    }
    return success;
  }

  static Future<bool> _connect() async {
    if (_isConnecting || isConnected) return isConnected;
    _isConnecting = true;

    final rng = Random.secure();
    final clientId = 'icharger_client_${rng.nextInt(9999999)}';

    _client = MqttServerClient('broker.hivemq.com', clientId);
    _client!.port = 1883;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      _client?.disconnect();
      isConnected = false;
      _isConnecting = false;
      return false;
    }

    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      isConnected = true;
      _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c == null || c.isEmpty) return;
        final recMess = c[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        try {
          final decoded = json.decode(payload) as Map<String, dynamic>;
          _dataStream.add(decoded);
        } catch (_) {
          // ignore malformed payloads
        }
      });

      _client!.subscribe('icharger/sync/$cloudCode', MqttQos.atLeastOnce);

      _isConnecting = false;
      return true;
    } else {
      _client?.disconnect();
      isConnected = false;
      _isConnecting = false;
      return false;
    }
  }

  static void _startAutoReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectTimer = Timer.periodic(_reconnectInterval, (_) async {
      if (isConnected || _isConnecting) return;
      final success = await _connect();
      if (success) {
        _stopAutoReconnect();
      }
    });
  }

  static void _stopAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  static void publishState(Map<String, BatteryInfo> batteries) {
    if (!isConnected || _client == null || cloudCode.isEmpty) return;

    final topic = 'icharger/sync/$cloudCode';
    final builder = MqttClientPayloadBuilder();

    final payloadMap = batteries.map((k, v) => MapEntry(k, v.toJson()));
    builder.addString(json.encode(payloadMap));

    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  static void publishLog(String batteryId, List<String> logs) {
    if (!isConnected || _client == null || cloudCode.isEmpty) return;

    final topic = 'icharger/sync/$cloudCode/logs/$batteryId';
    final builder = MqttClientPayloadBuilder();
    builder.addString(json.encode(logs));

    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  static void disconnect() {
    _client?.disconnect();
    _client = null;
    isConnected = false;
    _stopAutoReconnect();
  }
}
