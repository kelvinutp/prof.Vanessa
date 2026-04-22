import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_setup_native.dart' if (dart.library.html) 'mqtt_setup_web.dart' as helper;

MqttClient getMqttClient(String broker, String clientIdentifier) {
  final client = helper.createMqttClient(broker, clientIdentifier);
  helper.setupClient(client);
  return client;
}
