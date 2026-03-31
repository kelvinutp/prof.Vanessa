import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../models/battery_state.dart';
import 'serial_service.dart';

class LocalServerService {
  static final Map<String, BatteryInfo> currentBatteries = {};
  static HttpServer? _httpServer;
  static RawDatagramSocket? _udpSocket;
  static final Map<String, DateTime> activeClients = {};

  // PIN for mobile pairing
  static String pairingPin = '';
  static String _authToken = '';

  static void generatePin() {
    final rng = Random.secure();
    pairingPin = (1000 + rng.nextInt(8999)).toString();
    _authToken = base64Url.encode(utf8.encode('pin:$pairingPin'));
  }

  static void updateBatteryInfo(BatteryInfo info) {
    currentBatteries[info.batteryId] = info;
  }

  static Future<void> start() async {
    generatePin();
    await _resolveIp();

    Timer.periodic(const Duration(seconds: 2), (_) {
      final now = DateTime.now();
      activeClients.removeWhere((id, time) => now.difference(time).inSeconds > 5);
    });

    final router = Router();

    // ── helpers ──────────────────────────────────────────────
    Response unauthorized() => Response(
          401,
          body: json.encode({'error': 'Unauthorized. Wrong PIN token.'}),
          headers: {'Content-Type': 'application/json'},
        );

    bool isAuthorized(Request request) {
      final authHeader = request.headers['Authorization'] ?? '';
      final token =
          authHeader.startsWith('Bearer ') ? authHeader.substring(7) : authHeader;
      return token == _authToken;
    }

    // Public: health check
    router.get('/health', (Request req) => Response.ok('OK'));

    // Public: exchange PIN for token
    router.post('/auth', (Request req) async {
      final body = await req.readAsString();
      Map<String, dynamic> parsed = {};
      try {
        parsed = json.decode(body) as Map<String, dynamic>;
      } catch (_) {}
      final pin = parsed['pin']?.toString() ?? '';
      if (pin == pairingPin) {
        return Response.ok(
          json.encode({'token': _authToken}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return Response(
        403,
        body: json.encode({'error': 'Invalid PIN'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // Protected: batteries
    router.get('/batteries', (Request req) {
      if (!isAuthorized(req)) return unauthorized();
      
      final deviceId = req.headers['device-id'];
      if (deviceId != null && deviceId.isNotEmpty) {
        activeClients[deviceId] = DateTime.now();
      }

      final data = currentBatteries.map((k, v) => MapEntry(k, v.toJson()));
      return Response.ok(
          json.encode(data), headers: {'Content-Type': 'application/json'});
    });

    // Protected: terminal logs per battery
    router.get('/logs/<batteryId>', (Request req, String batteryId) {
      if (!isAuthorized(req)) return unauthorized();
      final logs = SerialService.getTerminalLogs(batteryId);
      return Response.ok(
          json.encode(logs), headers: {'Content-Type': 'application/json'});
    });

    final handler = Pipeline().addMiddleware(corsHeaders()).addHandler(router);
    _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8000);
    print('iCharger Host running on port 8000. PIN: $pairingPin');

    _startUdpBeacon();
  }

  /// Broadcasts a beacon on UDP 8001 every 3 seconds so mobile devices can discover us
  static Future<void> _startUdpBeacon() async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _udpSocket!.broadcastEnabled = true;
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_udpSocket == null) { timer.cancel(); return; }
      final payload = utf8.encode(json.encode({'service': 'iCharger', 'port': 8000}));
      _udpSocket!.send(payload, InternetAddress('255.255.255.255'), 8001);
    });
  }

  static Future<void> stop() async {
    await _httpServer?.close(force: true);
    _udpSocket?.close();
    _udpSocket = null;
  }

  static String get hostIp {
    try {
      // NetworkInterface.listSync is not available; use synchronous fallback
      // We cache from a previously resolved async call, or just show localhost.
      return _cachedIp ?? 'localhost';
    } catch (_) {
      return 'localhost';
    }
  }

  static String? _cachedIp;

  static Future<void> _resolveIp() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback) {
            _cachedIp = addr.address;
            return;
          }
        }
      }
    } catch (_) {}
  }
}
