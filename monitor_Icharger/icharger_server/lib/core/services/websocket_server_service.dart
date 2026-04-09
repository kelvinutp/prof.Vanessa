import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/battery_session.dart';

class WebSocketServerService {
  final List<WebSocketChannel> _clients = [];
  HttpServer? _server;

  Future<void> startServer(int port) async {
    final handler = webSocketHandler((WebSocketChannel webSocket, String? protocol) {
      _clients.add(webSocket);
      
      webSocket.stream.listen(
        (message) {
          // Clients are read-only for now as per requirements
        },
        onDone: () {
          _clients.remove(webSocket);
        },
      );
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    debugPrint('WebSocket server listening on ws://${_server?.address.address}:${_server?.port}');
  }

  void broadcastSessionUpdate(BatterySession session) {
    if (_clients.isEmpty) return;
    
    final payload = jsonEncode({
      'type': 'session_update',
      'data': session.toJson(),
    });

    for (var client in _clients) {
      client.sink.add(payload);
    }
  }

  void broadcastDataPoint(String sessionId, Map<String, dynamic> data) {
    if (_clients.isEmpty) return;

    final payload = jsonEncode({
      'type': 'data_point',
      'sessionId': sessionId,
      'data': data,
    });

    for (var client in _clients) {
      client.sink.add(payload);
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    for (var client in _clients) {
      client.sink.close();
    }
    _clients.clear();
  }
}
