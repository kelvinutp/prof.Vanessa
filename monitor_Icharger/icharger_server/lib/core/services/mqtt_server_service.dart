import 'dart:convert';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_helper.dart';
import 'unified_logger_service.dart';
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
    unifiedLogger.log('Starting MQTT Server connection with code: $serverCode', source: LogSource.mqtt);
    unifiedLogger.log('Server Identifier: $clientIdentifier', source: LogSource.mqtt);
    
    try {
      // Use the cross-platform helper
      client = getMqttClient(broker, clientIdentifier);
      
      client.keepAlivePeriod = 20;
      client.onDisconnected = () {
        unifiedLogger.log('MQTT Server triggered onDisconnected callback', source: LogSource.mqtt);
        _onDisconnected();
      };
      client.onConnected = () => unifiedLogger.log('MQTT Server triggered onConnected callback', source: LogSource.mqtt);
      client.onSubscribed = (topic) => unifiedLogger.log('MQTT Server subscribed to: $topic', source: LogSource.mqtt);

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

      unifiedLogger.log('Connecting to $broker...', source: LogSource.mqtt);
      await client.connect();
      
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        isConnected = true;
        unifiedLogger.log('Successfully connected to $broker on topic icharger/$serverCode', source: LogSource.mqtt);
        
        // Subscribe to inbound client messages
        unifiedLogger.log('Subscribing to icharger/$serverCode/inbound...', source: LogSource.mqtt);
        client.subscribe('icharger/$serverCode/inbound', MqttQos.atLeastOnce);
        
        client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          
          unifiedLogger.log('Received payload: $pt', source: LogSource.mqtt);
          onLogMessage?.call(pt, isSent: false);
          
          try {
            final payload = jsonDecode(pt);
            if (payload['type'] == 'client_connected') {
              unifiedLogger.log('Client connection event received', source: LogSource.mqtt);
              final welcomeMsg = jsonEncode({
                'type': 'welcome',
                'message': 'Welcome to ICharger Server!'
              });
              _publish(welcomeMsg);
            } else if (payload['type'] == 'test') {
              unifiedLogger.log('Test message received: ${payload['message']}', source: LogSource.mqtt);
            }
          } catch (e) {
            unifiedLogger.log('Error decoding incoming message: $e', source: LogSource.mqtt);
          }
        });
        
        // Publish initial online status
        broadcastStatus('online');
      } else {
        unifiedLogger.log('Connection state is not connected: ${client.connectionStatus!.state}', source: LogSource.mqtt);
      }
    } catch (e) {
      unifiedLogger.log('MQTT Server Connection EXCEPTION: $e', source: LogSource.mqtt);
      client.disconnect();
    }
  }

  void _onDisconnected() {
    isConnected = false;
    unifiedLogger.log('Internal disconnect handler triggered', source: LogSource.mqtt);
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
    unifiedLogger.log('Publishing to icharger/$serverCode: $message', source: LogSource.mqtt);
    onLogMessage?.call(message, isSent: true);
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage('icharger/$serverCode', MqttQos.atLeastOnce, builder.payload!);
  }

  void dispose() {
    unifiedLogger.log('Disposing MqttServerService', source: LogSource.mqtt);
    broadcastStatus('offline');
    client.disconnect();
  }
}


