import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/models/battery_session.dart';
import '../../core/models/battery_state.dart';
import '../../core/services/unified_logger_service.dart';
import '../widgets/setup_battery_dialog.dart';
import 'session_analysis_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  BatterySession? _selectedSession;

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionProvider>().sessions;
    final mqttService = context.watch<SessionProvider>().mqttService;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ICharger Multi-Battery Logger (Server)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (authProvider.authenticatedEmail != null) ...[
            Chip(
              avatar: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.shield, size: 12, color: Colors.white),
              ),
              label: Text(
                authProvider.authenticatedEmail!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout operator',
            onPressed: () {
              authProvider.logout();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // MQTT Info Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Broker: ${mqttService.broker}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.vpn_key, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Connection Code: ', style: const TextStyle(color: Colors.grey)),
                SelectableText(mqttService.serverCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.terminal),
                  tooltip: 'View MQTT Logs',
                  onPressed: () {
                    unifiedLogger.log('Clicked View MQTT Logs button', source: LogSource.ui);
                    _showMqttTerminal(context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  tooltip: 'Send Test Message',
                  onPressed: () {
                    unifiedLogger.log('Clicked Send Test Message button', source: LogSource.ui);
                    context.read<SessionProvider>().sendTestMessage();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Left Side: Grid of Batteries
                Expanded(
                  flex: 2,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return GestureDetector(
                        onTap: () {
                          unifiedLogger.log('Selected battery session: ${session.batteryName}', source: LogSource.ui);
                          setState(() => _selectedSession = session);
                        },
                        child: Card(
                          color: _selectedSession?.id == session.id ? Colors.blue.withValues(alpha: 0.1) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.batteryName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Stage: ${session.currentState.displayName}'),
                                Text('Cycle: ${session.currentCycle}'),
                                const Spacer(),
                                Row(
                                  children: [
                                    Icon(Icons.circle, size: 12, color: session.isActive ? Colors.green : Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(session.isActive ? 'Active' : 'Stopped'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Right Side: Details Panel
                if (_selectedSession != null)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade300))),
                      child: _buildDetailPanel(_selectedSession!),
                    ),
                  )
                else
                  const Expanded(
                    flex: 3,
                    child: Center(child: Text('Select a battery to view details')),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'analyze_fab',
            onPressed: () {
              unifiedLogger.log('Clicked Independent Analysis button (FAB)', source: LogSource.ui);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SessionAnalysisScreen(session: null),
                  settings: const RouteSettings(name: 'IndependentAnalysis'),
                ),
              );
            },
            tooltip: 'Independent Analysis',
            backgroundColor: Colors.orange,
            child: const Icon(Icons.psychology, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_fab',
            onPressed: () {
              unifiedLogger.log('Clicked Add Battery button (FAB)', source: LogSource.ui);
              showDialog(context: context, builder: (_) => const SetupBatteryDialog());
            },
            tooltip: 'Add Battery Session',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _showMqttTerminal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('MQTT Terminal (Server)'),
          content: SizedBox(
            width: 800,
            height: 500,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: Consumer<SessionProvider>(
                builder: (context, provider, child) {
                  return ListView.builder(
                    reverse: true,
                    itemCount: provider.mqttLogs.length,
                    itemBuilder: (context, index) {
                      final log = provider.mqttLogs[provider.mqttLogs.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          log['isSystem'] == true 
                            ? '[SYS] ${log['text']}'
                            : '${log['isSent'] == true ? '[OUT]' : '[IN]'} ${log['text']}',
                          style: TextStyle(
                            color: log['isSystem'] == true 
                              ? Colors.yellowAccent 
                              : (log['isSent'] == true ? Colors.blueAccent : Colors.greenAccent),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                          textAlign: log['isSystem'] == true ? TextAlign.center : (log['isSent'] == true ? TextAlign.right : TextAlign.left),
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

  Widget _buildDetailPanel(BatterySession session) {
    return Column(
      children: [
        // Upper Part: General Information
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Battery: ${session.batteryName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStateColor(session.currentState),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      session.currentState.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      unifiedLogger.log('Closed detail panel for ${session.batteryName}', source: LogSource.ui);
                      setState(() => _selectedSession = null);
                    },
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 20,
                    children: [
                      _infoTile('Capacity', '${session.nominalCapacity} mAh'),
                      _infoTile('Cycle', '${session.currentCycle}'),
                      _infoTile('Port', session.port),
                      _infoTile('Baud Rate', '${session.baudRate}'),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      unifiedLogger.log('Clicked Analyze button for ${session.batteryName}', source: LogSource.ui);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionAnalysisScreen(session: session),
                          settings: RouteSettings(name: 'Analysis_${session.batteryName}'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text('Analyze'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bottom Part: Terminal View
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              reverse: true, // Show latest first
              itemCount: session.logs.length,
              itemBuilder: (context, index) {
                final log = session.logs[session.logs.length - 1 - index];
                return Text(
                  log,
                  style: TextStyle(
                    color: log.startsWith('[SYSTEM]') ? Colors.orangeAccent : Colors.greenAccent, 
                    fontFamily: 'monospace', 
                    fontSize: 12
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Color _getStateColor(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return Colors.green;
      case BatteryState.discharging:
        return Colors.red;
      case BatteryState.rest:
        return Colors.orange;
      case BatteryState.finished:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

