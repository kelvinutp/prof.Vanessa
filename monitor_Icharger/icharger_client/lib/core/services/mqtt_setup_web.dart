import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String broker, String clientIdentifier) {
  // test.mosquitto.org uses /mqtt path for websockets
  return MqttBrowserClient('ws://$broker/mqtt', clientIdentifier);
}

void setupClient(MqttClient client) {
  final browserClient = client as MqttBrowserClient;
  browserClient.port = 8083;
  // Some browsers/proxies need this to avoid being blocked
  browserClient.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
}

