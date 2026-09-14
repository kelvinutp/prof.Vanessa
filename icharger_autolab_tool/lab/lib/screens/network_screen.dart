// lib/screens/network_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/network_service.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _controller = TextEditingController(text: 'ws://echo.websocket.events');

  @override
  Widget build(BuildContext context) {
    final netService = Provider.of<NetworkService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cross-Network Client/Server')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'WebSocket Server URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => netService.connectToServer(_controller.text),
              child: Text(netService.isConnected ? 'Disconnect' : 'Connect to Server'),
            ),
            const SizedBox(height: 24),
            Text('Status: ${netService.serverLog}', style: const TextStyle(fontSize: 16)),
            const Spacer(),
            ElevatedButton(
              onPressed: netService.isConnected
                  ? () => netService.sendCommand('PING_TELEMETRY')
                  : null,
              child: const Text('Send Test Command'),
            ),
          ],
        ),
      ),
    );
  }
}