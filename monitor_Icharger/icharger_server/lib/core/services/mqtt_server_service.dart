import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/battery_session.dart';

class MqttServerService {
  late MqttServerClient client;
  final String broker = 'test.mosquitto.org';
  late String serverCode;
  bool isConnected = false;
  
  Function(String message, {required bool isSent})? onLogMessage;

  MqttServerService() {
    serverCode = _generateServerCode();
  }

  String _generateServerCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(5, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<void> connect() async {
    final clientIdentifier = 'icharger_server_$serverCode';
    client = MqttServerClient(broker, clientIdentifier);
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    
    // Set Last Will and Testament
    final lwtTopic = 'icharger/$serverCode';
    final lwtMessage = jsonEncode({
      'type': 'status',
      'state': 'offline',
      'message': 'Server disconnected unexpectedly. Reboot required.'
    });
    
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .withWillTopic(lwtTopic)
        .withWillMessage(lwtMessage)
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .startClean();
    client.connectionMessage = connMessage;

    try {
      await client.connect();
      isConnected = true;
      debugPrint('MQTT connected to $broker on topic icharger/$serverCode');
      
      // Subscribe to inbound client messages
      client.subscribe('icharger/$serverCode/inbound', MqttQos.atLeastOnce);
      
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        
        onLogMessage?.call(pt, isSent: false);
        
        try {
          final payload = jsonDecode(pt);
          if (payload['type'] == 'client_connected') {
            final welcomeMsg = jsonEncode({
              'type': 'welcome',
              'message': 'Welcome to ICharger Server!'
            });
            _publish(welcomeMsg);
            debugPrint('Client connected: sent broadcase welcome message.');
          } else if (payload['type'] == 'test') {
            debugPrint('Received test message from client: ${payload['message']}');
          }
        } catch (e) {
          debugPrint('Error decoding incoming message: $e');
        }
      });
      
      // Publish initial online status
      broadcastStatus('online');
    } catch (e) {
      debugPrint('MQTT Connection failed: $e');
      client.disconnect();
    }
  }

  void _onDisconnected() {
    isConnected = false;
    debugPrint('MQTT Disconnected');
  }

  void broadcastStatus(String state) {
    if (!isConnected) return;
    
    final payload = jsonEncode({
      'type': 'status',
      'state': state,
    });
    
    _publish(payload);
  }

  void broadcastSessionUpdate(BatterySession session) {
    if (!isConnected) return;
    
    final payload = jsonEncode({
      'type': 'session_update',
      'data': session.toJson(),
    });
    
    _publish(payload);
  }

  void broadcastDataPoint(String sessionId, Map<String, dynamic> data) {
    if (!isConnected) return;

    final payload = jsonEncode({
      'type': 'data_point',
      'sessionId': sessionId,
      'data': data,
    });

    _publish(payload);
  }

  void broadcastTestMessage() {
    if (!isConnected) return;
    
    final payload = jsonEncode({
      'type': 'test',
      'message': 'Manual test from server'
    });
    
    _publish(payload);
  }

  void _publish(String message) {
    onLogMessage?.call(message, isSent: true);
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage('icharger/$serverCode', MqttQos.atLeastOnce, builder.payload!);
  }

  void dispose() {
    broadcastStatus('offline');
    client.disconnect();
  }
}
