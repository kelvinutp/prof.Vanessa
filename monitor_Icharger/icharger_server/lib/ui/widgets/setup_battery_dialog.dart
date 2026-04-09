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
              final session = BatterySession(
                id: const Uuid().v4(),
                batteryName: _batteryName,
                nominalCapacity: _nominalCapacity,
                startingCycle: _startingCycle,
                savePath: _savePath,
                port: _selectedPort!,
                baudRate: _baudRate,
              );
              context.read<SessionProvider>().addSession(session);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Start Monitoring'),
          ),
        ],
      ),
    );
  }
}
