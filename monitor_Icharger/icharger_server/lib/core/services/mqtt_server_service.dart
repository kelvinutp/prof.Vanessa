import 'dart:convert';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_helper.dart';
import 'logger_service.dart';
import '../models/battery_session.dart';

class MqttServerService {
  late MqttClient client;
  final String broker = 'broker.emqx.io';
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
    logger.log('Starting MQTT Server connection with code: $serverCode');
    logger.log('Server Identifier: $clientIdentifier');
    
    try {
      // Use the cross-platform helper
      client = getMqttClient(broker, clientIdentifier);
      
      client.keepAlivePeriod = 20;
      client.onDisconnected = () {
        logger.log('MQTT Server triggered onDisconnected callback');
        _onDisconnected();
      };
      client.onConnected = () => logger.log('MQTT Server triggered onConnected callback');
      client.onSubscribed = (topic) => logger.log('MQTT Server subscribed to: $topic');

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

      logger.log('Connecting to $broker...');
      await client.connect();
      
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        isConnected = true;
        logger.log('Successfully connected to $broker on topic icharger/$serverCode');
        
        // Subscribe to inbound client messages
        logger.log('Subscribing to icharger/$serverCode/inbound...');
        client.subscribe('icharger/$serverCode/inbound', MqttQos.atLeastOnce);
        
        client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          
          logger.log('Received payload: $pt');
          onLogMessage?.call(pt, isSent: false);
          
          try {
            final payload = jsonDecode(pt);
            if (payload['type'] == 'client_connected') {
              logger.log('Client connection event received');
              final welcomeMsg = jsonEncode({
                'type': 'welcome',
                'message': 'Welcome to ICharger Server!'
              });
              _publish(welcomeMsg);
            } else if (payload['type'] == 'test') {
              logger.log('Test message received: ${payload['message']}');
            }
          } catch (e) {
            logger.log('Error decoding incoming message: $e');
          }
        });
        
        // Publish initial online status
        broadcastStatus('online');
      } else {
        logger.log('Connection state is not connected: ${client.connectionStatus!.state}');
      }
    } catch (e) {
      logger.log('MQTT Server Connection EXCEPTION: $e');
      client.disconnect();
    }
  }

  void _onDisconnected() {
    isConnected = false;
    logger.log('Internal disconnect handler triggered');
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
    logger.log('Publishing to icharger/$serverCode: $message');
    onLogMessage?.call(message, isSent: true);
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage('icharger/$serverCode', MqttQos.atLeastOnce, builder.payload!);
  }

  void dispose() {
    logger.log('Disposing MqttServerService');
    broadcastStatus('offline');
    client.disconnect();
  }
}


