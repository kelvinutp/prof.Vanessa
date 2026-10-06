// lib/screens/icharger_screen.dart (Updated to fix deprecated value & dead code)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/usb_service.dart';

class IChargerScreen extends StatelessWidget {
  const IChargerScreen({super.key});

  Color _getStatusColor(SerialConnectionState state) {
    switch (state) {
      case SerialConnectionState.connected:
        return Colors.greenAccent;
      case SerialConnectionState.reconnecting:
        return Colors.orangeAccent;
      case SerialConnectionState.busy:
      case SerialConnectionState.error:
        return Colors.redAccent;
      case SerialConnectionState.connecting:
      case SerialConnectionState.scanning:
        return Colors.blueAccent;
      case SerialConnectionState.disconnected:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usbService = Provider.of<UsbService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('iCharger - Voltage & Serial Config')),
      appBar: AppBar(
        title: const Text('iCharger - Voltage & Serial Config'),
        actions: [
          if (usbService.isConnected ||
              usbService.connectionState == SerialConnectionState.reconnecting)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Disconnect Port',
              onPressed: () => usbService.disconnect(),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => usbService.getAvailableDevices(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan USB Devices'),
            // Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(usbService.connectionState),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 14,
                    color: _getStatusColor(usbService.connectionState),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${usbService.connectionState.name.toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(usbService.connectionState),
                          ),
                        ),
                        Text(
                          usbService.statusMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (usbService.connectionState == SerialConnectionState.reconnecting)
                    TextButton(
                      onPressed: () => usbService.cancelReconnect(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.orangeAccent)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Controls Row
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: usbService.connectionState == SerialConnectionState.scanning
                      ? null
                      : () => usbService.getAvailableDevices(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Ports / Devices'),
                ),
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Baud Rate',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    initialValue: usbService.selectedBaudRate,
                    items: [9600, 19200, 38400, 57600, 115200, 230400]
                        .map((rate) => DropdownMenuItem(value: rate, child: Text('$rate baud')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) usbService.setBaudRate(val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Select Baud Rate', border: OutlineInputBorder()),
              initialValue: usbService.selectedBaudRate,
              items: [9600, 19200, 38400, 57600, 115200]
                  .map((rate) => DropdownMenuItem(value: rate, child: Text('$rate baud')))
                  .toList(),
              onChanged: (val) => usbService.setBaudRate(val!),

            // Discovered Ports / Devices List
            const Text(
              'Discovered Ports / Chips (Windows COM & USB CDC):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text('Available Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
              child: usbService.devices.isEmpty
                  ? Center(
                      child: Text(
                        'No serial ports detected.\nClick "Scan Ports" or connect a USB-to-Serial converter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: usbService.devices.length,
                      itemBuilder: (context, index) {
                        final device = usbService.devices[index];
                        final isThisDeviceConnected = usbService.isConnected &&
                            usbService.selectedDevice == device;

                        return Card(
                          color: isThisDeviceConnected
                              ? const Color(0xFF1E3A2B)
                              : const Color(0xFF1E1E1E),
                          child: ListTile(
                            leading: Icon(
                              Icons.developer_board,
                              color: isThisDeviceConnected ? Colors.greenAccent : Colors.blueAccent,
                            ),
                            title: Text(
                              '${device.deviceId} - ${device.deviceName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Chipset: ${device.chipset} | Path: ${device.hardwarePath}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isThisDeviceConnected
                                    ? Colors.red.shade800
                                    : Colors.blueAccent,
                              ),
                              onPressed: () {
                                if (isThisDeviceConnected) {
                                  usbService.disconnect();
                                } else {
                                  usbService.connect(device);
                                }
                              },
                              child: Text(isThisDeviceConnected ? 'Disconnect' : 'Connect'),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const Text('Live Voltage Measurement:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

            // Live Voltage Reading
            const Text(
              'Live Voltage Measurement:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Center(
              child: Text(
                '${usbService.liveVoltage.toStringAsFixed(3)} V',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}