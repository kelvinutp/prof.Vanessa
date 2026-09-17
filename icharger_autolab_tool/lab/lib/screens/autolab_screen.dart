// lib/screens/autolab_screen.dart (Updated to fix deprecated value)
import 'package:flutter/material.dart';

class AutolabScreen extends StatefulWidget {
  const AutolabScreen({super.key});

  @override
  State<AutolabScreen> createState() => _AutolabScreenState();
}

class _AutolabScreenState extends State<AutolabScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String currentRange = '1A';
  String bandwidthEI = 'High speed';
  double setpointDC = 0.0;
  bool dsgInput = false;
  String waveSignal = 'Sine';
  int cycles = 1;
  double integrationTime = 0.1;
  double frequencySweep = 1000.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autolab Configuration & Measure')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Current Range'),
                initialValue: currentRange,
                items: ['1A','100 mA','10 mA','1 mA','100 µA','10 µA','1 µA','100 nA','10 nA'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => currentRange = val!),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Bandwidth of EI (Hz)'),
                initialValue: bandwidthEI,
                items: ['High stability','High speed','Ultra high speed'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => bandwidthEI = val!),
              ),              
              TextFormField(
                decoration: const InputDecoration(labelText: 'Setpoint DC (V)'),
                keyboardType: TextInputType.number,
                initialValue: setpointDC.toString(),
                onSaved: (val) => setpointDC = double.parse(val!),
              ),
              SwitchListTile(
                title: const Text('DSG Input Active'),
                value: dsgInput,
                onChanged: (val) => setState(() => dsgInput = val),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Wave Signal'),
                initialValue: waveSignal,
                items: ['Sine', '5 sines', '15 sines'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => waveSignal = val!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Number of Cycles'),
                keyboardType: TextInputType.number,
                initialValue: cycles.toString(),
                onSaved: (val) => cycles = int.parse(val!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Maximum Integration Time (s)'),
                keyboardType: TextInputType.number,
                initialValue: integrationTime.toString(),
                onSaved: (val) => integrationTime = double.parse(val!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Frequency Sweep Start (Hz)'),
                keyboardType: TextInputType.number,
                initialValue: frequencySweep.toString(),
                onSaved: (val) => frequencySweep = double.parse(val!),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Autolab configuration applied successfully! Starting measurement...')),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Initialize Sweep & Measure'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}