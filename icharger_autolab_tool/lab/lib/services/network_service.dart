import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class NetworkService with ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;
  String serverLog = "Disconnected";

  void connectToServer(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      isConnected = true;
      serverLog = "Connected to remote server: $url";
      notifyListeners();

      _channel!.stream.listen((message) {
        serverLog = "Received: $message";
        notifyListeners();
      }, onError: (error) {
        isConnected = false;
        serverLog = "Error: $error";
        notifyListeners();
      });
    } catch (e) {
      serverLog = "Connection Failed: $e";
      isConnected = false;
      notifyListeners();
    }
  }

  void sendCommand(String command) {
    if (isConnected && _channel != null) {
      _channel!.sink.add(command);
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}