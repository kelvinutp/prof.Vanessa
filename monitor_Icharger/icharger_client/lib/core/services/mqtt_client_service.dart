import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttClientService {
  late MqttServerClient client;
  final String broker = 'test.mosquitto.org';
  bool isConnected = false;
  String? activeServerCode;
  
  Function(String message, {required bool isSent})? onLogMessage;
  
  final Function(Map<String, dynamic> payload) onMessageReceived;
  final VoidCallback onDisconnected;

  MqttClientService({required this.onMessageReceived, required this.onDisconnected});

  Future<bool> connect(String serverCode) async {
    final clientIdentifier = 'icharger_client_${DateTime.now().millisecondsSinceEpoch}';
    client = MqttServerClient(broker, clientIdentifier);
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.onDisconnected = _handleDisconnect;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean();
    client.connectionMessage = connMessage;

    try {
      await client.connect();
      isConnected = true;
      activeServerCode = serverCode;
      debugPrint('MQTT Client connected to $broker');
      
      // Subscribe to the server's topic
      client.subscribe('icharger/$serverCode', MqttQos.atLeastOnce);

      // Publish connection event to server
      _publish('icharger/$serverCode/inbound', jsonEncode({'type': 'client_connected'}));
      
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        
        onLogMessage?.call(pt, isSent: false);
        
        try {
          final payload = jsonDecode(pt);
          onMessageReceived(payload);
        } catch (e) {
          debugPrint('Error decoding MQTT message: $e');
        }
      });
      
      return true;
    } catch (e) {
      debugPrint('MQTT Client Connection failed: $e');
      client.disconnect();
      return false;
    }
  }

  void _handleDisconnect() {
    isConnected = false;
    onDisconnected();
    debugPrint('MQTT Client Disconnected');
  }

  void disconnect() {
    client.disconnect();
  }

  void publishTestMessage() {
    if (!isConnected || activeServerCode == null) return;
    _publish('icharger/$activeServerCode/inbound', jsonEncode({'type': 'test', 'message': 'Manual test from client'}));
    debugPrint('Published test message to server');
  }

  void _publish(String topic, String message) {
    onLogMessage?.call(message, isSent: true);
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }
}
