import 'dart:async';
import 'package:flutter/material.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _selectedMinutes = 10;
  int _remainingSeconds = 600;
  Timer? _timer;
  bool _isRunning = false;

  final TextEditingController _customMinutesController = TextEditingController(text: '10');

  void _setDuration(int minutes) {
    if (_isRunning) return;
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _customMinutesController.text = minutes.toString();
    });
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _stopTimer();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  String get _formattedTime {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _customMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Countdown Timer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueAccent, width: 4),
            ),
            child: Text(
              _formattedTime,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isRunning ? null : _startTimer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Start'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isRunning ? _stopTimer : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Pause'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _resetTimer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),
          const Text('Quick Preset Durations', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              ActionChip(label: const Text('5 min'), onPressed: () => _setDuration(5)),
              ActionChip(label: const Text('10 min'), onPressed: () => _setDuration(10)),
              ActionChip(label: const Text('30 min'), onPressed: () => _setDuration(30)),
              ActionChip(label: const Text('60 min'), onPressed: () => _setDuration(60)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Custom Duration (Minutes)', border: OutlineInputBorder()),
                  enabled: !_isRunning,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isRunning
                    ? null
                    : () {
                        final val = int.tryParse(_customMinutesController.text);
                        if (val != null && val > 0) {
                          _setDuration(val);
                        }
                      },
                child: const Text('Set Time'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}