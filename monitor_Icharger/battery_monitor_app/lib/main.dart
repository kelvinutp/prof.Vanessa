import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, RawDatagramSocket, InternetAddress, RawSocketEvent;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/battery_state.dart';
import 'services/server_service.dart';
import 'services/serial_service.dart';
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
        fontFamily: 'Roboto',
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
    if (isDesktop) LocalServerService.start();
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

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => batteries = Map.from(LocalServerService.currentBatteries));
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
    int baudrate = 9600;
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
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Baud Rate',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  dropdownColor: const Color(0xFF16213E),
                  value: baudrate,
                  items: [9600, 19200, 38400, 57600, 115200, 230400]
                      .map((b) =>
                          DropdownMenuItem(value: b, child: Text('$b')))
                      .toList(),
                  onChanged: (v) => setD(() => baudrate = v ?? 9600),
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
                  baudrate: baudrate,
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
          // ── PIN / Connection Panel ──────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F3460), Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering, color: Colors.cyanAccent, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Server Active — Awaiting Mobile Connection',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('IP: $ip:8000',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                          const SizedBox(width: 16),
                          const Text('Pairing PIN: ',
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('${batteries.length} battery(ies)',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('${portsWithStatus.length} port(s) found',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          // ── Battery Grid ───────────────────────────────────────
          Expanded(
            child: batteries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.battery_unknown,
                            size: 64, color: Colors.white12),
                        const SizedBox(height: 12),
                        const Text('No batteries monitored yet.',
                            style: TextStyle(color: Colors.white38)),
                        const SizedBox(height: 4),
                        const Text('Press + to bind a COM port.',
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
                          builder: (_) => BatteryDetailScreen(
                              batteryId: id, isDesktop: true)),
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

  Future<void> _startUdpScan() async {
    setState(() { _scanning = true; _status = 'Scanning local network for Desktop App…'; });
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8001);
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            try {
              final msg = json.decode(utf8.decode(datagram.data));
              if (msg['service'] == 'iCharger') {
                final ip = datagram.address.address;
                final port = msg['port'] ?? 8000;
                setState(() {
                  _discoveredIp = '$ip:$port';
                  _scanning = false;
                  _status = 'Desktop found at $_discoveredIp!';
                });
                _udpSocket?.close();
                _promptPin();
              }
            } catch (_) {}
          }
        }
      });

      // Timeout after 15 seconds
      Future.delayed(const Duration(seconds: 15), () {
        if (_scanning && mounted) {
          _udpSocket?.close();
          setState(() {
            _scanning = false;
            _status = 'No Desktop App found. Ensure it is running and on the same network.';
          });
        }
      });
    } catch (e) {
      setState(() { _scanning = false; _status = 'Scan error: $e'; });
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
            Text('Desktop found at $_discoveredIp\nEnter the 4-digit PIN displayed on the Desktop.',
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
              onPressed: () { Navigator.pop(ctx); setState(() => _discoveredIp = null); },
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
        body: json.encode({'pin': pin}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final token = (json.decode(res.body) as Map)['token'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backendUrl', _discoveredIp!);
        await prefs.setString('authToken', token);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ClientDashboard(
                backendUrl: _discoveredIp!,
                authToken: token,
              ),
            ),
          );
        }
      } else {
        setState(() => _status = 'Wrong PIN. Try again.');
      }
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    }
  }

  Future<void> _tryAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('backendUrl');
    final token = prefs.getString('authToken');
    if (url != null && token != null) {
      try {
        final res = await http
            .get(Uri.parse('http://$url/health'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200 && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ClientDashboard(backendUrl: url, authToken: token)),
          );
          return;
        }
      } catch (_) {}
    }
  }

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
              labelStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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
              const SizedBox(height: 8),
              const Text('Connect to a Desktop Host',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(_status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 24),
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
                        label: const Text('Auto-Scan Network'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
// ========== CLIENT DASHBOARD ==============================
// ==========================================================

class ClientDashboard extends StatefulWidget {
  final String backendUrl;
  final String authToken;
  const ClientDashboard(
      {super.key, required this.backendUrl, required this.authToken});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  Map<String, dynamic> batteries = {};
  Timer? _timer;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
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
        final res = await http
            .get(
              Uri.parse('http://${widget.backendUrl}/batteries'),
              headers: {'Authorization': 'Bearer ${widget.authToken}'},
            )
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          if (mounted) {
            setState(() {
              batteries = json.decode(res.body) as Map<String, dynamic>;
              isConnected = true;
            });
          }
        } else {
          if (mounted) setState(() => isConnected = false);
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
        title: const Text('iCharger Monitor — Client'),
        actions: [
          IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
              onPressed: _disconnect),
        ],
      ),
      body: Column(
        children: [
          // Connection banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: isConnected ? Colors.green[900] : Colors.red[900],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            width: double.infinity,
            child: Text(
              isConnected
                  ? '● Connected to ${widget.backendUrl}'
                  : '✕ Desktop App Not Currently Running — Cannot reach ${widget.backendUrl}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
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
                          isConnected
                              ? Icons.battery_unknown
                              : Icons.wifi_off,
                          size: 64,
                          color: Colors.white12,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isConnected
                              ? 'No batteries being monitored.'
                              : 'Desktop app is offline.',
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
// ========== SHARED UI =====================================
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
          side: BorderSide(color: stateColor.withOpacity(0.4), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.bateria,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: stateColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(data.state.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              _row('Voltage',  '${data.voltage} V',    Colors.cyanAccent),
              _row('Current',  '${data.current} A',    Colors.amberAccent),
              _row('Capacity', '${data.capacity} mAh', Colors.greenAccent),
              _row('Cycle',    data.ciclo,              Colors.purpleAccent),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.usb, size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text('${data.port} @ ${data.baudrate}',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
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
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
