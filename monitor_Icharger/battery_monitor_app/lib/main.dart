import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/battery_state.dart';
import 'services/server_service.dart';
import 'services/serial_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IChargerApp());
}

class IChargerApp extends StatelessWidget {
  const IChargerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iCharger Native Monitor',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
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
  bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (isDesktop) {
      _startServer();
    }
  }

  Future<void> _startServer() async {
    await LocalServerService.start();
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return const HostDesktopScreen();
    } else {
      return const ClientViewerScreen();
    }
  }
}

// ============================================
// ========== HOST DESKTOP MODE ===============
// ============================================

class HostDesktopScreen extends StatefulWidget {
  const HostDesktopScreen({super.key});

  @override
  State<HostDesktopScreen> createState() => _HostDesktopScreenState();
}

class _HostDesktopScreenState extends State<HostDesktopScreen> {
  Map<String, BatteryInfo> batteries = {};
  List<String> comPorts = [];

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        batteries = Map.from(LocalServerService.currentBatteries);
      });
    });
  }

  void _refreshPorts() {
    setState(() {
      comPorts = SerialService.getAvailablePorts();
    });
  }

  void _showAddBatteryDialog() {
    final nameController = TextEditingController();
    final capacityController = TextEditingController();
    final cycleController = TextEditingController(text: '1');
    final folderController = TextEditingController();
    String? selectedPort;
    int baudrate = 9600;
    
    _refreshPorts();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Confirmar datos de Bateria (Host)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'COM Port'),
                    items: comPorts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) => setDialogState(() => selectedPort = val),
                  ),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Baud Rate'),
                    value: baudrate,
                    items: [9600, 19200, 38400, 57600, 115200, 230400]
                        .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                        .toList(),
                    onChanged: (val) => setDialogState(() => baudrate = val ?? 9600),
                  ),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Bateria')),
                  TextField(controller: capacityController, decoration: const InputDecoration(labelText: 'Capacidad nominal')),
                  TextField(controller: cycleController, decoration: const InputDecoration(labelText: 'Ciclo')),
                  TextField(controller: folderController, decoration: const InputDecoration(labelText: 'Ruta de folder (vacio = raiz)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (selectedPort == null || nameController.text.isEmpty) return;
                  BatteryInfo info = BatteryInfo(
                    batteryId: nameController.text,
                    port: selectedPort!,
                    baudrate: baudrate,
                    bateria: nameController.text,
                    capacidad: capacityController.text,
                    ciclo: cycleController.text,
                    folder: folderController.text,
                  );
                  LocalServerService.updateBatteryInfo(info);
                  SerialService.startMonitoring(info, (updatedInfo) {
                     LocalServerService.updateBatteryInfo(updatedInfo);
                  });
                  Navigator.pop(context);
                },
                child: const Text('Start'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      appBar: AppBar(
        title: const Text('iCharger Monitor (Desktop Server)'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshPorts),
        ],
      ),
      body: batteries.isEmpty
          ? const Center(child: Text('No monitoring active. Click + to bind physical COM port.', style: TextStyle(fontSize: 18)))
          : GridRenderer(batteries: batteries.values.toList(), isDesktop: true, onStop: (id) => SerialService.stopMonitoring(id)),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBatteryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================
// ========== CLIENT VIEWER MODE ==============
// ============================================

class ClientViewerScreen extends StatefulWidget {
  const ClientViewerScreen({super.key});

  @override
  State<ClientViewerScreen> createState() => _ClientViewerScreenState();
}

class _ClientViewerScreenState extends State<ClientViewerScreen> {
  Map<String, dynamic> batteries = {};
  Timer? _timer;
  String backendUrl = '192.168.1.100:8000';
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      backendUrl = prefs.getString('backendUrl') ?? '192.168.1.100:8000';
    });
    _startPolling();
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backendUrl', url);
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final response = await http.get(Uri.parse('http://$backendUrl/batteries')).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          setState(() {
            batteries = (json.decode(response.body) as Map<String, dynamic>);
            isConnected = true;
          });
        } else {
          setState(() => isConnected = false);
        }
      } catch (e) {
        setState(() => isConnected = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _configureSync() {
    final ipController = TextEditingController(text: backendUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configure Host Target'),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(labelText: 'Desktop IP & Port (e.g. 192.168.x.x:8000)'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                _saveUrl(ipController.text);
                setState(() { backendUrl = ipController.text; });
                _startPolling();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iCharger Monitor (Client)'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _configureSync),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: isConnected ? Colors.green[900] : Colors.red[900],
            width: double.infinity,
            child: Text(
              isConnected ? 'Connected to Host: $backendUrl' : 'Desktop App Not Currently Running. Cannot reach $backendUrl',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Expanded(
            child: batteries.isEmpty
              ? const Center(child: Text('No data from backbone sync...'))
              : GridRenderer(
                  batteries: batteries.values.map((v) => BatteryInfo.fromJson(v)).toList(),
                  isDesktop: false,
                  onStop: (id) => {}, 
                ),
          )
        ],
      )
    );
  }
}

// ============================================
// ========== SHARED UI COMPONENTS ============
// ============================================

class GridRenderer extends StatelessWidget {
  final List<BatteryInfo> batteries;
  final bool isDesktop;
  final Function(String) onStop;

  const GridRenderer({super.key, required this.batteries, required this.isDesktop, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: isDesktop 
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: batteries.length,
              itemBuilder: (context, index) => SizedBox(width: 350, child: BatteryCard(data: batteries[index], onStop: onStop, isDesktop: isDesktop))
            )
          : ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: batteries.length,
              itemBuilder: (context, index) => BatteryCard(data: batteries[index], onStop: onStop, isDesktop: isDesktop)
            ),
    );
  }
}

class BatteryCard extends StatelessWidget {
  final BatteryInfo data;
  final Function(String) onStop;
  final bool isDesktop;

  const BatteryCard({super.key, required this.data, required this.onStop, required this.isDesktop});

  Color _getStatusColor(String? state) {
    switch (state) {
      case 'charging': return Colors.green;
      case 'discharging': return Colors.red;
      case 'rest': return Colors.orange;
      case 'finished': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Battery: ${data.bateria}', style: Theme.of(context).textTheme.headlineSmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusColor(data.state), borderRadius: BorderRadius.circular(4)),
                  child: Text((data.state).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Voltage:', '${data.voltage} V'),
            _buildInfoRow('Current:', '${data.current} A'),
            _buildInfoRow('Capacity:', '${data.capacity} mAh'),
            _buildInfoRow('Cycle:', data.ciclo),
            const Spacer(),
            Text('Port: ${data.port} @ ${data.baudrate}'),
            Text('Status: ${data.status}'),
            Text('Last Update: ${data.lastUpdate}'),
            const SizedBox(height: 10),
            if (isDesktop && data.status == 'monitoring')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onStop(data.batteryId),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                  child: const Text('STOP MONITORING LOCAL PORT'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 18, color: Colors.blueAccent)),
        ],
      ),
    );
  }
}
