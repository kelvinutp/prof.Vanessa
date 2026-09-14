// lib/screens/icharger_screen.dart (Updated to fix deprecated value & dead code)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/usb_service.dart';

class IChargerScreen extends StatelessWidget {
  const IChargerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usbService = Provider.of<UsbService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('iCharger - Voltage & Serial Config')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => usbService.getAvailableDevices(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan USB Devices'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Select Baud Rate', border: OutlineInputBorder()),
              initialValue: usbService.selectedBaudRate,
              items: [9600, 19200, 38400, 57600, 115200]
                  .map((rate) => DropdownMenuItem(value: rate, child: Text('$rate baud')))
                  .toList(),
              onChanged: (val) => usbService.setBaudRate(val!),
            ),
            const SizedBox(height: 20),
            const Text('Available Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: usbService.devices.length,
                itemBuilder: (context, index) {
                  final device = usbService.devices[index];
                  return Card(
                    child: ListTile(
                      title: Text(device.deviceName),
                      subtitle: Text('ID: ${device.deviceId}'),
                      trailing: ElevatedButton(
                        onPressed: () => usbService.connect(device),
                        child: Text(usbService.isConnected ? 'Connected' : 'Connect'),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const Text('Live Voltage Measurement:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Center(
              child: Text(
                '${usbService.liveVoltage.toStringAsFixed(3)} V',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.greenAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}