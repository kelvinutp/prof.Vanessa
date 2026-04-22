import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_helper.dart';
import 'logger_service.dart';

class MqttClientService {
  late MqttClient client;
  final String broker = 'broker.emqx.io';
  bool isConnected = false;
  String? activeServerCode;
  
  Function(String message, {required bool isSent})? onLogMessage;
  
  final Function(Map<String, dynamic> payload) onMessageReceived;
  final VoidCallback onDisconnected;

  MqttClientService({required this.onMessageReceived, required this.onDisconnected});


  Future<bool> connect(String serverCode) async {
    final clientIdentifier = 'icharger_client_${DateTime.now().millisecondsSinceEpoch}';
    logger.log('Starting MQTT connection attempt with code: $serverCode');
    logger.log('Client Identifier: $clientIdentifier');
    
    try {
      // Use the cross-platform helper to create the client
      client = getMqttClient(broker, clientIdentifier);
      
      client.keepAlivePeriod = 20;
      client.onDisconnected = () {
        logger.log('MQTT Client triggered onDisconnected callback');
        _handleDisconnect();
      };
      client.onConnected = () => logger.log('MQTT Client triggered onConnected callback');
      client.onSubscribed = (topic) => logger.log('MQTT Client subscribed to: $topic');
      client.onSubscribeFail = (topic) => logger.log('MQTT Client FAILED to subscribe to: $topic');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientIdentifier)
          .startClean();
      client.connectionMessage = connMessage;

      logger.log('Connecting to $broker...');
      await client.connect();
      
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        isConnected = true;
        activeServerCode = serverCode;
        logger.log('Successfully connected to $broker');
        
        // Subscribe to the server's topic
        logger.log('Subscribing to icharger/$serverCode...');
        client.subscribe('icharger/$serverCode', MqttQos.atLeastOnce);

        // Publish connection event to server
        logger.log('Publishing client_connected event...');
        _publish('icharger/$serverCode/inbound', jsonEncode({'type': 'client_connected'}));
        
        client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          
          logger.log('Received payload: $pt');
          onLogMessage?.call(pt, isSent: false);
          
          try {
            final payload = jsonDecode(pt);
            onMessageReceived(payload);
          } catch (e) {
            logger.log('Error decoding MQTT message: $e');
          }
        });
        
        return true;
      } else {
        logger.log('Connection state is not connected: ${client.connectionStatus!.state}');
        return false;
      }
    } catch (e) {
      logger.log('MQTT Client Connection EXCEPTION: $e');
      client.disconnect();
      return false;
    }
  }

  void _handleDisconnect() {
    isConnected = false;
    onDisconnected();
    logger.log('Internal disconnect handler triggered');
  }

  void disconnect() {
    logger.log('Manual disconnect requested');
    client.disconnect();
  }

  void publishTestMessage() {
    if (!isConnected || activeServerCode == null) {
      logger.log('Cannot publish test message: Not connected');
      return;
    }
    _publish('icharger/$activeServerCode/inbound', jsonEncode({'type': 'test', 'message': 'Manual test from client'}));
  }

  void _publish(String topic, String message) {
    logger.log('Publishing to $topic: $message');
    onLogMessage?.call(message, isSent: true);
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }
}


