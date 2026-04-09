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
  final _ipController = TextEditingController(text: 'ws://localhost:8080');
  BatterySession? _selectedSession;

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
              Text(provider.isConnected ? 'Connected' : 'Disconnected', 
                style: TextStyle(color: provider.isConnected ? Colors.green : Colors.red)),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'Server Address'))),
                IconButton(
                  icon: Icon(provider.isConnected ? Icons.link_off : Icons.link),
                  onPressed: () {
                    if (provider.isConnected) {
                      provider.disconnect();
                    } else {
                      provider.connect(_ipController.text);
                    }
                  },
                ),
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
