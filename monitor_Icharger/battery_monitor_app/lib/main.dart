import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const IChargerApp());
}

class IChargerApp extends StatelessWidget {
  const IChargerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iCharger Monitor',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BatteryMonitorScreen(),
    );
  }
}

class BatteryMonitorScreen extends StatefulWidget {
  const BatteryMonitorScreen({super.key});

  @override
  State<BatteryMonitorScreen> createState() => _BatteryMonitorScreenState();
}

class _BatteryMonitorScreenState extends State<BatteryMonitorScreen> {
  Map<String, dynamic> batteries = {};
  List<dynamic> availablePorts = [];
  Timer? _timer;
  final String apiUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    _fetchBatteries();
    _fetchPorts();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchBatteries();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBatteries() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/batteries'));
      if (response.statusCode == 200) {
        setState(() {
          batteries = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching batteries: $e');
    }
  }

  Future<void> _fetchPorts() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/ports'));
      if (response.statusCode == 200) {
        setState(() {
          availablePorts = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching ports: $e');
    }
  }

  Future<void> _startMonitoring(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/monitor/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        _fetchBatteries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Error: $e')),
      );
    }
  }

  Future<void> _stopMonitoring(String batteryId) async {
    try {
      await http.post(Uri.parse('$apiUrl/monitor/stop/$batteryId'));
      _fetchBatteries();
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('iCharger Battery Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchBatteries();
              _fetchPorts();
            },
          ),
        ],
      ),
      body: batteries.isEmpty
          ? const Center(child: Text('No batteries monitored. Click + to add.'))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: isWide
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: batteries.length,
                      itemBuilder: (context, index) {
                        String id = batteries.keys.elementAt(index);
                        return SizedBox(
                          width: 350,
                          child: BatteryCard(
                            data: batteries[id],
                            onStop: () => _stopMonitoring(id),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      itemCount: batteries.length,
                      itemBuilder: (context, index) {
                        String id = batteries.keys.elementAt(index);
                        return BatteryCard(
                          data: batteries[id],
                          onStop: () => _stopMonitoring(id),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBatteryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddBatteryDialog() {
    final nameController = TextEditingController();
    final capacityController = TextEditingController();
    final cycleController = TextEditingController(text: '1');
    final folderController = TextEditingController();
    String? selectedPort;
    int baudrate = 9600;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Battery Monitor'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'COM Port'),
                    items: availablePorts.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['device'],
                        child: Text('${p['device']} (${p['description']})'),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedPort = val),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Battery Number/Name'),
                  ),
                  TextField(
                    controller: capacityController,
                    decoration: const InputDecoration(labelText: 'Nominal Capacity (mAh)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: cycleController,
                    decoration: const InputDecoration(labelText: 'Starting Cycle'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: folderController,
                    decoration: const InputDecoration(labelText: 'Save Folder (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (selectedPort == null || nameController.text.isEmpty) return;
                  _startMonitoring({
                    'battery_id': nameController.text,
                    'port': selectedPort,
                    'baudrate': baudrate,
                    'bateria': nameController.text,
                    'capacidad': capacityController.text,
                    'ciclo': cycleController.text,
                    'folder': folderController.text.isEmpty ? '.' : folderController.text,
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
}

class BatteryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onStop;

  const BatteryCard({super.key, required this.data, required this.onStop});

  Color _getStatusColor(String? state) {
    switch (state) {
      case 'charging':
        return Colors.green;
      case 'discharging':
        return Colors.red;
      case 'rest':
        return Colors.orange;
      case 'finished':
        return Colors.blue;
      default:
        return Colors.grey;
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
                Text(
                  'Battery: ${data['bateria']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(data['state']),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (data['state'] ?? 'unknown').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Voltage:', '${data['voltage']} V'),
            _buildInfoRow('Current:', '${data['current']} A'),
            _buildInfoRow('Capacity:', '${data['capacity']} mAh'),
            _buildInfoRow('Cycle:', '${data['ciclo']}'),
            const Spacer(),
            Text('Port: ${data['port']} @ ${data['baudrate']}'),
            Text('Status: ${data['status']}'),
            if (data['last_update'] != null) Text('Last Update: ${data['last_update']}'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: data['status'] == 'monitoring' ? onStop : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                child: const Text('STOP MONITORING'),
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
