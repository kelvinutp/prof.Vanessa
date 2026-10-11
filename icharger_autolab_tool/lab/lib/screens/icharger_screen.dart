// lib/screens/icharger_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/usb_service.dart';

class IChargerScreen extends StatefulWidget {
  const IChargerScreen({super.key});

  @override
  State<IChargerScreen> createState() => _IChargerScreenState();
}

class _IChargerScreenState extends State<IChargerScreen> {
  dynamic _selectedDevice;

  @override
  void initState() {
    super.initState();
    // Setup notification listener hook to surface messages via SnackBars
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usbService = Provider.of<UsbService>(context, listen: false);
      usbService.onNotificationTriggered = (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
        );
      };
    });
  }

  Future<void> _handleConnect(BuildContext context, UsbService usbService, dynamic device) async {
    setState(() => _selectedDevice = device);
    
    // Check if user manually selected a baud rate after a failure or tries auto-baud first
    bool success;
    if (usbService.connectionState == ConnectionStateEnum.baudRateFailed) {
      success = await usbService.connectWithManualBaud(device, usbService.selectedBaudRate);
    } else {
      success = await usbService.connectWithAutoBaud(device);
    }

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected successfully at ${usbService.selectedBaudRate} baud!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usbService = Provider.of<UsbService>(context);
    
    final isConnected = usbService.connectionState == ConnectionStateEnum.connected;
    final isAutoBauding = usbService.connectionState == ConnectionStateEnum.autoBauding;
    final isConnecting = usbService.connectionState == ConnectionStateEnum.connecting || isAutoBauding;
    final hasFailed = usbService.connectionState == ConnectionStateEnum.baudRateFailed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('iCharger - Voltage & Serial Config'),
        actions: [
          if (isConnected)
            IconButton(
              icon: Icon(usbService.isRecording ? Icons.stop_circle : Icons.fiber_manual_record),
              color: usbService.isRecording ? Colors.red : Colors.white,
              tooltip: usbService.isRecording ? 'Stop & Save CSV' : 'Start CSV Recording',
              onPressed: () {
                if (usbService.isRecording) {
                  usbService.stopAndSaveCsvFile();
                } else {
                  usbService.startCsvRecording();
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: isConnecting ? null : () => usbService.getAvailableDevices(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan USB Devices'),
            ),
            const SizedBox(height: 16),
            
            // Manual Baud Rate Selector / Fallback Control
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Baud Rate (Manual / Auto-Selected)', 
                border: OutlineInputBorder(),
              ),
              value: usbService.selectedBaudRate,
              items: [9600, 19200, 38400, 57600, 115200]
                  .map((rate) => DropdownMenuItem(value: rate, child: Text('$rate baud')))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  usbService.setBaudRate(val);
                  if (_selectedDevice != null && hasFailed) {
                    usbService.connectWithManualBaud(_selectedDevice, val);
                  }
                }
              },
            ),
            
            // Warning Banner if Auto-Baud Failed
            if (hasFailed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ Auto-baud detection failed. Select your baud rate manually from the dropdown above to establish connection.',
                  style: TextStyle(color: Colors.brown, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available Devices:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (isAutoBauding)
                  const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Auto-bauding...', style: TextStyle(color: Colors.blue, fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: usbService.devices.length,
                itemBuilder: (context, index) {
                  final device = usbService.devices[index];
                  final deviceName = device.productName ?? device.deviceName ?? 'USB COM Device $index';
                  final deviceId = device.deviceId?.toString() ?? 'COM Port';

                  return Card(
                    child: ListTile(
                      title: Text(deviceName),
                      subtitle: Text('ID: $deviceId'),
                      trailing: ElevatedButton(
                        onPressed: isConnecting ? null : () => _handleConnect(context, usbService, device),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (isConnected && _selectedDevice == device) ? Colors.green : null,
                        ),
                        child: Text((isConnected && _selectedDevice == device) ? 'Connected' : (isConnecting ? 'Connecting...' : 'Connect')),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            
            // Live Voltage Display & CSV status header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Voltage Measurement:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (usbService.isRecording)
                  const Chip(
                    avatar: CircleRadiusIndicator(color: Colors.red),
                    label: Text('Recording CSV...'),
                    backgroundColor: Colors.redAccent,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 11),
                  ),
              ],
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${usbService.liveVoltage.toStringAsFixed(3)} V',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircleRadiusIndicator extends StatelessWidget {
  final Color color;
  const CircleRadiusIndicator({super.key, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}