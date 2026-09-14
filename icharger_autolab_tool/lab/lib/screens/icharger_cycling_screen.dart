import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:usb_serial/usb_serial.dart';
import '../services/usb_service.dart';

class IChargerCyclingScreen extends StatefulWidget {
  const IChargerCyclingScreen({super.key});

  @override
  State<IChargerCyclingScreen> createState() => _IChargerCyclingScreenState();
}

class _IChargerCyclingScreenState extends State<IChargerCyclingScreen> {
  final _formKey = GlobalKey<FormState>();
  String batteryName = '';
  double nominalVoltage = 3.7;
  double capacityMah = 2000.0;
  bool isLogging = false;
  IOSink? _csvSink;
  String? _lastFilePath;

  Future<void> _startDataCollection(UsbService usbService) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = batteryName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${directory.path}/battery_${sanitizedName}_$timestamp.csv');
      
      _csvSink = file.openWrite();
      _csvSink!.writeln('Timestamp,BatteryName,NominalVoltage,CapacityMah,RawData');
      
      setState(() {
        isLogging = true;
        _lastFilePath = file.path;
      });

      usbService.onDataReceived = (dataString) {
        if (isLogging && _csvSink != null) {
          final now = DateTime.now().toIso8601String();
          _csvSink!.writeln('$now,"$batteryName",$nominalVoltage,$capacityMah,"$dataString"');
        }
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logging data to: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start CSV log: $e')),
      );
    }
  }

  Future<void> _stopDataCollection(UsbService usbService) async {
    usbService.onDataReceived = null;
    await _csvSink?.flush();
    await _csvSink?.close();
    _csvSink = null;
    setState(() {
      isLogging = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data collection stopped and saved to CSV.')),
    );
  }

  @override
  void dispose() {
    _csvSink?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usbService = Provider.of<UsbService>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('USB & Baud Rate Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => usbService.getAvailableDevices(),
                icon: const Icon(Icons.refresh),
                label: const Text('Scan USB Devices'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Baud Rate', border: OutlineInputBorder()),
                initialValue: usbService.selectedBaudRate,
                items: [9600, 19200, 38400, 57600, 115200]
                    .map((rate) => DropdownMenuItem(value: rate, child: Text('$rate baud')))
                    .toList(),
                onChanged: (val) => usbService.setBaudRate(val!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<UsbDevice>(
                decoration: const InputDecoration(labelText: 'Select USB Port / Device', border: OutlineInputBorder()),
                items: usbService.devices.map((device) {
                  return DropdownMenuItem(
                    value: device,
                    child: Text(device.deviceName ?? 'Device ID: ${device.deviceId}'),
                  );
                }).toList(),
                onChanged: (device) {
                  if (device != null) usbService.connect(device);
                },
              ),
              const Divider(height: 40),
              const Text('Battery Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Battery Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Enter battery name' : null,
                onSaved: (val) => batteryName = val!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nominal Voltage (V)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                initialValue: nominalVoltage.toString(),
                validator: (val) => double.tryParse(val ?? '') == null ? 'Enter valid voltage' : null,
                onSaved: (val) => nominalVoltage = double.parse(val!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Capacity (mAh)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                initialValue: capacityMah.toString(),
                validator: (val) => double.tryParse(val ?? '') == null ? 'Enter valid capacity' : null,
                onSaved: (val) => capacityMah = double.parse(val!),
              ),
              const SizedBox(height: 24),
              if (!isLogging)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
                  onPressed: usbService.isConnected ? () => _startDataCollection(usbService) : null,
                  icon: const Icon(Icons.fiber_manual_record, color: Colors.white),
                  label: const Text('Start Data Collection (Save to CSV)', style: TextStyle(color: Colors.white)),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(50)),
                  onPressed: () => _stopDataCollection(usbService),
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text('Stop Data Collection', style: TextStyle(color: Colors.white)),
                ),
              if (_lastFilePath != null) ...[
                const SizedBox(height: 15),
                Text('Last saved file:\n$_lastFilePath', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}