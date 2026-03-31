import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, RawDatagramSocket, InternetAddress, RawSocketEvent;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'models/battery_state.dart';
import 'services/server_service.dart';
import 'services/serial_service.dart';
import 'services/cloud_sync_service.dart';
import 'screens/battery_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IChargerApp());
}

class IChargerApp extends StatelessWidget {
  const IChargerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iCharger Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.amberAccent,
          surface: const Color(0xFF1A1A2E),
        ),
        useMaterial3: true,
      ),
      home: const MainRouter(),
    );
  }
}

class MainRouter extends StatefulWidget {
  const MainRouter({super.key});
  @override
  State<MainRouter> createState() => _MainRouterState();
}

class _MainRouterState extends State<MainRouter> {
  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    if (isDesktop) {
      LocalServerService.start();
      // Start MQTT cloud publishing loop on desktop
      CloudSyncService.connectDesktop().then((_) {
        Timer.periodic(const Duration(seconds: 1), (_) {
          CloudSyncService.publishState(LocalServerService.currentBatteries);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      isDesktop ? const HostDesktopScreen() : const ClientPairingScreen();
}

// ==========================================================
// ========== DESKTOP HOST MODE =============================
// ==========================================================

class HostDesktopScreen extends StatefulWidget {
  const HostDesktopScreen({super.key});
  @override
  State<HostDesktopScreen> createState() => _HostDesktopScreenState();
}

class _HostDesktopScreenState extends State<HostDesktopScreen> {
  Map<String, BatteryInfo> batteries = {};
  List<Map<String, dynamic>> portsWithStatus = [];
  Map<String, DateTime> activeClients = {};

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          batteries = Map.from(LocalServerService.currentBatteries);
          activeClients = Map.from(LocalServerService.activeClients);
        });
      }
    });
  }

  void _refreshPorts() {
    setState(() => portsWithStatus = SerialService.getAvailablePortsWithStatus());
  }

  void _showAddBatteryDialog() {
    final nameCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();
    final cycleCtrl = TextEditingController(text: '1');
    final folderCtrl = TextEditingController();
    String? selectedPort;
    _refreshPorts();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Nueva Batería', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // COM Port dropdown with busy indicator
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'COM Port',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  dropdownColor: const Color(0xFF16213E),
                  items: portsWithStatus.map((p) {
                    final isBusy = p['busy'] as bool;
                    return DropdownMenuItem<String>(
                      value: p['port'] as String,
                      enabled: !isBusy,
                      child: Row(
                        children: [
                          Icon(
                            isBusy ? Icons.lock : Icons.usb,
                            size: 16,
                            color: isBusy ? Colors.red[300] : Colors.green[300],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            p['label'] as String,
                            style: TextStyle(
                                color: isBusy ? Colors.red[300] : Colors.white),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setD(() => selectedPort = val),
                ),
                const SizedBox(height: 4),
                Text(
                  'Baud rate will be auto-detected.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 8),
                _field(nameCtrl, 'Bateria (ID)'),
                _field(capacityCtrl, 'Capacidad nominal'),
                _field(cycleCtrl, 'Ciclo inicial'),
                _field(folderCtrl, 'Ruta de folder (vacío = dir. actual)'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (selectedPort == null || nameCtrl.text.isEmpty) return;
                final info = BatteryInfo(
                  batteryId: nameCtrl.text,
                  port: selectedPort!,
                  baudrate: 0, // Auto-detected by SerialService
                  bateria: nameCtrl.text,
                  capacidad: capacityCtrl.text,
                  ciclo: cycleCtrl.text,
                  folder: folderCtrl.text,
                );
                LocalServerService.updateBatteryInfo(info);
                SerialService.startMonitoring(info, (updated) {
                  LocalServerService.updateBatteryInfo(updated);
                });
                _refreshPorts();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
              child: const Text('Iniciar', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      }),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ip = LocalServerService.hostIp;
    final pin = LocalServerService.pairingPin;
    final cloudCode = CloudSyncService.cloudCode;
    final cloudConnected = CloudSyncService.isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('iCharger Monitor — Host Desktop',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _refreshPorts,
              tooltip: 'Refresh COM Ports'),
        ],
      ),
      body: Column(
        children: [
          // ── Server Info Panel ─────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F3460), Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Local network info + PIN
                Row(
                  children: [
                    const Icon(Icons.wifi_tethering, color: Colors.cyanAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Local Network',
                              style: TextStyle(color: Colors.white38, fontSize: 10)),
                          Text('$ip:8000',
                              style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Text('Local PIN: ',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(pin,
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 4)),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 16),
                // Row 2: MQTT Cloud info
                Row(
                  children: [
                    Icon(
                      cloudConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: cloudConnected ? Colors.greenAccent : Colors.red[300],
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cloudConnected
                                ? 'Cloud Relay Active (broker.hivemq.com)'
                                : 'Cloud Relay Offline',
                            style: TextStyle(
                              color: cloudConnected ? Colors.greenAccent : Colors.red[300],
                              fontSize: 11,
                            ),
                          ),
                          if (cloudConnected && cloudCode.isNotEmpty)
                            Text('Cloud Code: $cloudCode',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (cloudConnected && cloudCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(cloudCode,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 4)),
                      ),
                  ],
                ),
                // Row 3: Connected mobile clients
                if (activeClients.isNotEmpty) ...[
                  const Divider(color: Colors.white10, height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.phone_android,
                          color: Colors.white38, size: 16),
                      const SizedBox(width: 6),
                      const Text('Connected Devices: ',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: activeClients.keys
                              .map((id) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.teal[900],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(id,
                                        style: const TextStyle(
                                            color: Colors.tealAccent,
                                            fontSize: 10)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Battery Grid ──────────────────────────────────────
          Expanded(
            child: batteries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.battery_unknown,
                            size: 64, color: Color(0x1AFFFFFF)),
                        SizedBox(height: 12),
                        Text('No batteries monitored yet.',
                            style: TextStyle(color: Colors.white38)),
                        SizedBox(height: 4),
                        Text('Press + to auto-detect a COM port.',
                            style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  )
                : _BatteryGrid(
                    batteries: batteries.values.toList(),
                    isDesktop: true,
                    onTap: (id) => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              BatteryDetailScreen(batteryId: id, isDesktop: true)),
                    ),
                    onStop: (id) {
                      SerialService.stopMonitoring(id);
                      _refreshPorts();
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBatteryDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Battery'),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
      ),
    );
  }
}

// ==========================================================
// ========== MOBILE CLIENT — PAIRING SCREEN ================
// ==========================================================

Future<String> _getDeviceId() async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final d = await info.androidInfo;
      return d.id;
    } else if (Platform.isIOS) {
      final d = await info.iosInfo;
      return d.identifierForVendor ?? 'ios-${DateTime.now().millisecondsSinceEpoch}';
    }
  } catch (_) {}
  return 'device-${DateTime.now().millisecondsSinceEpoch}';
}

class ClientPairingScreen extends StatefulWidget {
  const ClientPairingScreen({super.key});
  @override
  State<ClientPairingScreen> createState() => _ClientPairingScreenState();
}

class _ClientPairingScreenState extends State<ClientPairingScreen> {
  String? _discoveredIp;
  bool _scanning = false;
  String _status = 'Tap Scan to find the Desktop App on your network.';
  RawDatagramSocket? _udpSocket;

  @override
  void initState() {
    super.initState();
    _tryAutoConnect();
  }

  @override
  void dispose() {
    _udpSocket?.close();
    super.dispose();
  }

  Future<void> _tryAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('backendUrl');
    final token = prefs.getString('authToken');
    if (url != null && token != null && mounted) {
      try {
        final res = await http
            .get(Uri.parse('http://$url/health'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200 && mounted) {
          _goToDashboard(url, token, 'local');
          return;
        }
      } catch (_) {}
    }
    // Try cloud auto-reconnect
    final savedCode = prefs.getString('cloudCode');
    if (savedCode != null && mounted) {
      setState(() => _status = 'Reconnecting via Cloud Relay…');
      final ok = await CloudSyncService.connectMobile(savedCode);
      if (ok && mounted) {
        _goToCloudDashboard(savedCode);
      } else if (mounted) {
        setState(() => _status = 'Tap Scan or use Cloud Connect to pair.');
      }
    }
  }

  Future<void> _startUdpScan() async {
    setState(() {
      _scanning = true;
      _status = 'Scanning local network for Desktop App…';
    });
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8001,
          reusePort: true);
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            try {
              final msg = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
              if (msg['service'] == 'iCharger') {
                final discoveredIp = '${dg.address.address}:${msg['port'] ?? 8000}';
                setState(() {
                  _discoveredIp = discoveredIp;
                  _scanning = false;
                  _status = 'Desktop found at $discoveredIp!';
                });
                _udpSocket?.close();
                _udpSocket = null;
                _promptPin();
              }
            } catch (_) {}
          }
        }
      });

      Future.delayed(const Duration(seconds: 15), () {
        if (_scanning && mounted) {
          _udpSocket?.close();
          _udpSocket = null;
          setState(() {
            _scanning = false;
            _status = 'No Desktop App found on local network.';
          });
        }
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _status = 'Scan error: $e';
      });
    }
  }

  void _promptPin() {
    if (_discoveredIp == null) return;
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Enter Pairing PIN', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Desktop found at $_discoveredIp\nEnter the 4-digit PIN shown on the Desktop.',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _discoveredIp = null);
              },
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              Navigator.pop(ctx);
              await _authenticate(pin);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Connect', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _authenticate(String pin) async {
    if (_discoveredIp == null) return;
    setState(() => _status = 'Authenticating with PIN…');
    try {
      final res = await http.post(
        Uri.parse('http://$_discoveredIp/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': pin}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final token = (jsonDecode(res.body) as Map)['token'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backendUrl', _discoveredIp!);
        await prefs.setString('authToken', token);
        if (mounted) _goToDashboard(_discoveredIp!, token, 'local');
      } else {
        if (mounted) setState(() => _status = 'Wrong PIN. Try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Connection failed: $e');
    }
  }

  void _manualEntry() {
    final ipCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Manual Connection', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ipCtrl,
          decoration: const InputDecoration(
            labelText: 'Host IP:Port',
            hintText: '192.168.x.x:8000',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _discoveredIp = ipCtrl.text.trim());
              _promptPin();
            },
            child: const Text('Pair'),
          ),
        ],
      ),
    );
  }

  void _cloudConnectDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Row(
          children: const [
            Icon(Icons.cloud, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Cloud Connect', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 6-digit Cloud Code displayed on the desktop.\nThis works across any network worldwide.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 6),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.length != 6) return;
              Navigator.pop(ctx);
              setState(() => _status = 'Connecting to Cloud Relay…');
              final ok = await CloudSyncService.connectMobile(code);
              if (ok && mounted) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('cloudCode', code);
                _goToCloudDashboard(code);
              } else if (mounted) {
                setState(() => _status = 'Could not connect to cloud. Check the code and try again.');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text('Connect', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _goToDashboard(String url, String token, String mode) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => ClientDashboard(backendUrl: url, authToken: token)),
    );
  }

  void _goToCloudDashboard(String code) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CloudClientDashboard(cloudCode: code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_find, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text('iCharger Monitor',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Connect to a Desktop Host',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(_status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 20),
              if (_scanning)
                const CircularProgressIndicator(color: Colors.cyanAccent)
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startUdpScan,
                        icon: const Icon(Icons.search),
                        label: const Text('Auto-Scan (Same Network)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _cloudConnectDialog,
                        icon: const Icon(Icons.cloud),
                        label: const Text('Cloud Connect (Any Network)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _manualEntry,
                        icon: const Icon(Icons.edit),
                        label: const Text('Enter IP Manually'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// ========== LOCAL NETWORK CLIENT DASHBOARD ================
// ==========================================================

class ClientDashboard extends StatefulWidget {
  final String backendUrl;
  final String authToken;
  const ClientDashboard({super.key, required this.backendUrl, required this.authToken});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  Map<String, dynamic> batteries = {};
  Timer? _timer;
  bool isConnected = false;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _getDeviceId().then((id) {
      _deviceId = id;
      _startPolling();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final res = await http.get(
          Uri.parse('http://${widget.backendUrl}/batteries'),
          headers: {
            'Authorization': 'Bearer ${widget.authToken}',
            'device-id': _deviceId, // Track this device on server
          },
        ).timeout(const Duration(seconds: 2));

        if (res.statusCode == 200 && mounted) {
          setState(() {
            batteries = jsonDecode(res.body) as Map<String, dynamic>;
            isConnected = true;
          });
        } else if (mounted) {
          setState(() => isConnected = false);
        }
      } catch (_) {
        if (mounted) setState(() => isConnected = false);
      }
    });
  }

  void _disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('backendUrl');
    await prefs.remove('authToken');
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ClientPairingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final batList = batteries.values
        .map((v) => BatteryInfo.fromJson(v as Map<String, dynamic>))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text('iCharger Monitor — Local'),
        actions: [
          IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
              onPressed: _disconnect),
        ],
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: isConnected ? Colors.green[900] : Colors.red[900],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            width: double.infinity,
            child: Text(
              isConnected
                  ? '● Connected to ${widget.backendUrl}'
                  : '✕ Desktop App Not Currently Running — Cannot reach ${widget.backendUrl}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: isConnected && batteries.isNotEmpty
                ? _BatteryGrid(
                    batteries: batList,
                    isDesktop: false,
                    onTap: (id) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatteryDetailScreen(
                          batteryId: id,
                          isDesktop: false,
                          backendUrl: widget.backendUrl,
                          authToken: widget.authToken,
                        ),
                      ),
                    ),
                    onStop: (_) {},
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected ? Icons.battery_unknown : Icons.wifi_off,
                          size: 64, color: Colors.white12,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isConnected ? 'No batteries being monitored.' : 'Desktop app is offline.',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// ========== CLOUD (MQTT) CLIENT DASHBOARD =================
// ==========================================================

class CloudClientDashboard extends StatefulWidget {
  final String cloudCode;
  const CloudClientDashboard({super.key, required this.cloudCode});

  @override
  State<CloudClientDashboard> createState() => _CloudClientDashboardState();
}

class _CloudClientDashboardState extends State<CloudClientDashboard> {
  Map<String, dynamic> batteries = {};
  DateTime? _lastReceived;
  late StreamSubscription<Map<String, dynamic>> _sub;

  bool get isConnected =>
      _lastReceived != null &&
      DateTime.now().difference(_lastReceived!).inSeconds < 10;

  @override
  void initState() {
    super.initState();
    _sub = CloudSyncService.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          batteries = data;
          _lastReceived = DateTime.now();
        });
      }
    });
    // Refresh connected indicator every second
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _disconnect() async {
    CloudSyncService.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cloudCode');
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ClientPairingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final batList = batteries.values
        .map((v) => BatteryInfo.fromJson(v as Map<String, dynamic>))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.cloud, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Text('Cloud: ${widget.cloudCode}'),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
              onPressed: _disconnect),
        ],
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: isConnected ? Colors.green[900] : Colors.red[900],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            width: double.infinity,
            child: Text(
              isConnected
                  ? '● Cloud Relay Active — Desktop is sending data'
                  : '✕ Desktop App Not Currently Active — Waiting for data on Cloud Code ${widget.cloudCode}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: isConnected && batteries.isNotEmpty
                ? _BatteryGrid(
                    batteries: batList,
                    isDesktop: false,
                    onTap: (_) {}, // Cloud mode: no terminal view (logs not relayed via MQTT yet)
                    onStop: (_) {},
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.cloud_off, size: 64, color: Color(0x1AFFFFFF)),
                        SizedBox(height: 12),
                        Text('Waiting for data from Desktop…',
                            style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// ========== SHARED UI WIDGETS =============================
// ==========================================================

class _BatteryGrid extends StatelessWidget {
  final List<BatteryInfo> batteries;
  final bool isDesktop;
  final Function(String) onTap;
  final Function(String) onStop;

  const _BatteryGrid({
    required this.batteries,
    required this.isDesktop,
    required this.onTap,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: batteries.length,
        itemBuilder: (ctx, i) => SizedBox(
          width: 300,
          child: _BatteryCard(
              data: batteries[i], isDesktop: true, onTap: onTap, onStop: onStop),
        ),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: batteries.length,
        itemBuilder: (ctx, i) => _BatteryCard(
            data: batteries[i], isDesktop: false, onTap: onTap, onStop: onStop),
      );
    }
  }
}

class _BatteryCard extends StatelessWidget {
  final BatteryInfo data;
  final bool isDesktop;
  final Function(String) onTap;
  final Function(String) onStop;

  const _BatteryCard({
    required this.data,
    required this.isDesktop,
    required this.onTap,
    required this.onStop,
  });

  Color _stateColor(String s) {
    switch (s) {
      case 'charging':    return Colors.green;
      case 'discharging': return Colors.redAccent;
      case 'rest':        return Colors.orange;
      case 'finished':    return Colors.blueAccent;
      default:            return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _stateColor(data.state);
    return GestureDetector(
      onTap: () => onTap(data.batteryId),
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.all(8),
        color: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: stateColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(data.bateria,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: stateColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(data.state.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              _row('Voltage',  '${data.voltage} V',    Colors.cyanAccent),
              _row('Current',  '${data.current} A',    Colors.amberAccent),
              _row('Capacity', '${data.capacity} mAh', Colors.greenAccent),
              _row('Cycle',    data.ciclo,              Colors.purpleAccent),
              const Spacer(),
              if (data.baudrate > 0)
                Row(
                  children: [
                    const Icon(Icons.usb, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text('${data.port} @ ${data.baudrate} baud',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                )
              else
                Row(
                  children: const [
                    Icon(Icons.search, size: 12, color: Colors.white38),
                    SizedBox(width: 4),
                    Text('Auto-detecting baud rate…',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.open_in_new, size: 12, color: Colors.cyanAccent),
                  const SizedBox(width: 4),
                  const Text('Tap to view terminal',
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  const Spacer(),
                  if (isDesktop && data.status == 'monitoring')
                    GestureDetector(
                      onTap: () => onStop(data.batteryId),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red[900],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('STOP',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
