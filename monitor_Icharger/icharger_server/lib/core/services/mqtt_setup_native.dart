import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String broker, String clientIdentifier) {
  return MqttServerClient(broker, clientIdentifier);
}

void setupClient(MqttClient client) {
  final serverClient = client as MqttServerClient;
  serverClient.port = 1883;
}
