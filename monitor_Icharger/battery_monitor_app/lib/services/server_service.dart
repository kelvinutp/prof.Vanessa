import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../models/battery_state.dart';

class LocalServerService {
  static final Map<String, BatteryInfo> currentBatteries = {};
  static var _server;

  static void updateBatteryInfo(BatteryInfo info) {
    currentBatteries[info.batteryId] = info;
  }

  static Future<void> start() async {
    final router = Router();

    // Endpoints
    router.get('/batteries', (Request request) {
      final data = currentBatteries.map((k, v) => MapEntry(k, v.toJson()));
      return Response.ok(json.encode(data),
          headers: {'Content-Type': 'application/json'});
    });
    
    router.get('/health', (Request request) {
      return Response.ok("OK");
    });

    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addHandler(router);

    _server = await io.serve(handler, '0.0.0.0', 8000);
    print('Host Server running on localhost:${_server.port}');
  }

  static Future<void> stop() async {
    if (_server != null) {
      await _server.close();
    }
  }
}
