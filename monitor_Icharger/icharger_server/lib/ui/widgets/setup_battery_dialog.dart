import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/session_provider.dart';
import '../../core/models/battery_session.dart';
import 'package:uuid/uuid.dart';

class SetupBatteryDialog extends StatefulWidget {
  const SetupBatteryDialog({super.key});

  @override
  State<SetupBatteryDialog> createState() => _SetupBatteryDialogState();
}

class _SetupBatteryDialogState extends State<SetupBatteryDialog> {
  final _formKey = GlobalKey<FormState>();
  String _batteryName = '';
  int _nominalCapacity = 3000;
  int _startingCycle = 1;
  String _savePath = '';
  String? _selectedPort;
  final int _baudRate = 9600;

  @override
  void initState() {
    super.initState();
    _loadDefaultPath();
  }

  void _loadDefaultPath() async {
    final path = await context.read<SessionProvider>().getDefaultPath();
    setState(() => _savePath = path);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final ports = provider.serialService.listAvailablePorts();

    return AlertDialog(
      title: const Text('Add New Battery Session'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPort,
                decoration: const InputDecoration(labelText: 'COM Port'),
                items: ports.map((port) {
                  final isBusy = provider.serialService.isPortBusy(port);
                  return DropdownMenuItem(
                    value: port,
                    enabled: !isBusy,
                    child: Text(port + (isBusy ? ' (Busy)' : '')),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPort = val),
                validator: (val) => val == null ? 'Select a port' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Battery Name'),
                onChanged: (val) => _batteryName = val,
                validator: (val) => val!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nominal Capacity (mAh)'),
                keyboardType: TextInputType.number,
                initialValue: '3000',
                onChanged: (val) => _nominalCapacity = int.tryParse(val) ?? 3000,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Starting Cycle'),
                keyboardType: TextInputType.number,
                initialValue: '1',
                onChanged: (val) => _startingCycle = int.tryParse(val) ?? 1,
              ),
              Row(
                children: [
                  Expanded(child: Text('Path: $_savePath', overflow: TextOverflow.ellipsis)),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      String? selectedDirectory = await FilePicker.getDirectoryPath();
                      if (selectedDirectory != null) {
                        setState(() => _savePath = selectedDirectory);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedPort != null) {
              _showConfirmation();
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  void _showConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Data'),
        content: Text('Port: $_selectedPort\nBattery: $_batteryName\nCapacity: $_nominalCapacity\nCycle: $_startingCycle\nPath: $_savePath'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Edit')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startBaudRateDetection();
            },
            child: const Text('Start Monitoring'),
          ),
        ],
      ),
    );
  }

  void _startBaudRateDetection() async {
    final provider = context.read<SessionProvider>();
    final port = _selectedPort!;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Detecting Baud Rate...')),
          ],
        ),
      ),
    );

    int? detected = await provider.detectBaudRate(port, (log) {});

    if (mounted) {
      Navigator.pop(context); // popup loading dialog
    }

    if (detected != null) {
      _finalizeSetup(detected);
    } else {
      if (mounted) {
        _showManualBaudRatePrompt();
      }
    }
  }

  void _showManualBaudRatePrompt() {
    final controller = TextEditingController(text: '9600');
    showDialog(
      context: context,
      builder: (promptCtx) => AlertDialog(
        title: const Text('Detection Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not automatically determine the baud rate.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Manual Baud Rate (e.g. 9600)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(promptCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              int manuallyEntered = int.tryParse(controller.text) ?? 9600;
              Navigator.pop(promptCtx);
              _finalizeSetup(manuallyEntered);
            },
            child: const Text('Use Manual'),
          ),
        ],
      ),
    );
  }

  void _finalizeSetup(int finalBaudRate) {
    if (!mounted) return;
    final session = BatterySession(
      id: const Uuid().v4(),
      batteryName: _batteryName,
      nominalCapacity: _nominalCapacity,
      startingCycle: _startingCycle,
      savePath: _savePath,
      port: _selectedPort!,
      baudRate: finalBaudRate,
    );
    context.read<SessionProvider>().addSession(session);
    Navigator.pop(context); // Close the overarching SetupDialog
  }
}
