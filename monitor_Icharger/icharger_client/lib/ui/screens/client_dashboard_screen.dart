import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/client_provider.dart';
import '../../core/models/battery_session.dart';
import '../widgets/graphing_panel.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  final _codeController = TextEditingController();
  BatterySession? _selectedSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastCode = context.read<ClientProvider>().lastServerCode;
      if (lastCode != null) {
        _codeController.text = lastCode;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientProvider>();
    final sessions = provider.sessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ICharger Remote Monitor'),
        actions: [
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: provider.isConnected ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(provider.isConnected ? 'Connected' : 'Disconnected', 
                style: TextStyle(color: provider.isConnected ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Server Offline Alert
          if (provider.serverOfflineMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Row(
                children: [
                   const Icon(Icons.error, color: Colors.red),
                   const SizedBox(width: 8),
                   Expanded(child: Text(provider.serverOfflineMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ],
              ),
            ),

          // Welcome Message Alert
          if (provider.welcomeMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade100,
              width: double.infinity,
              child: Row(
                children: [
                   const Icon(Icons.info, color: Colors.green),
                   const SizedBox(width: 8),
                   Expanded(child: Text(provider.welcomeMessage!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                   IconButton(
                     icon: const Icon(Icons.close, color: Colors.green),
                     onPressed: provider.clearWelcomeMessage,
                   ),
                ],
              ),
            ),


          // Connection Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'Enter Server Connection Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key)))),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: Icon(provider.isConnected ? Icons.link_off : Icons.link),
                  onPressed: () {
                    if (provider.isConnected) {
                      provider.disconnect();
                    } else {
                      provider.connect(_codeController.text);
                    }
                  },
                ),
                const SizedBox(width: 8),
                if (provider.isConnected) ...[
                  IconButton.filled(
                    icon: const Icon(Icons.terminal),
                    tooltip: 'View MQTT Logs',
                    onPressed: () => _showMqttTerminal(context),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Test'),
                    onPressed: provider.sendTestMessage,
                  ),
                ]
              ],
            ),
          ),
          
          Expanded(
            child: Row(
              children: [
                // Sessions List
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return ListTile(
                        selected: _selectedSession?.id == session.id,
                        title: Text(session.batteryName),
                        subtitle: Text('Stage: ${session.currentState.displayName}'),
                        onTap: () => setState(() => _selectedSession = session),
                        trailing: Icon(Icons.circle, size: 12, color: session.isActive ? Colors.green : Colors.grey),
                      );
                    },
                  ),
                ),
                
                // Details Panel
                if (_selectedSession != null)
                  Expanded(
                    flex: 4,
                    child: _buildClientDetailPanel(_selectedSession!),
                  )
                else
                  const Expanded(flex: 4, child: Center(child: Text('Select a battery'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _showGraph = false;

  void _showMqttTerminal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('MQTT Terminal (Client)'),
          content: SizedBox(
            width: 800,
            height: 500,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: Consumer<ClientProvider>(
                builder: (context, provider, child) {
                  return ListView.builder(
                    reverse: true,
                    itemCount: provider.mqttLogs.length,
                    itemBuilder: (context, index) {
                      final log = provider.mqttLogs[provider.mqttLogs.length - 1 - index];
                      final isSent = log['isSent'] as bool;
                      final text = log['text'] as String;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          '${isSent ? '[OUT]' : '[IN]'} $text',
                          style: TextStyle(
                            color: isSent ? Colors.blueAccent : Colors.greenAccent,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          textAlign: isSent ? TextAlign.right : TextAlign.left,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClientDetailPanel(BatterySession session) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Battery: ${session.batteryName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Terminal'), icon: Icon(Icons.code)),
                      ButtonSegment(value: true, label: Text('Graphs'), icon: Icon(Icons.show_chart)),
                    ],
                    selected: {_showGraph},
                    onSelectionChanged: (set) => setState(() => _showGraph = set.first),
                  ),
                ],
              ),
              const Divider(),
              Text('Nominal: ${session.nominalCapacity} mAh'),
              Text('Current Status: ${session.currentState.displayName}'),
            ],
          ),
        ),
        Expanded(
          child: _showGraph 
            ? GraphingPanel(data: session.dataHistory)
            : Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  reverse: true,
                  itemCount: session.dataHistory.length,
                  itemBuilder: (context, index) {
                    final data = session.dataHistory[session.dataHistory.length - 1 - index];
                    return Text(
                      data.rawLine,
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 10),
                    );
                  },
                ),
              ),
        ),
      ],
    );
  }
}
