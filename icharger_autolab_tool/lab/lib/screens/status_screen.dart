// lib/screens/status_screen.dart
import 'package:flutter/material.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Status & Diagnostics')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent),
            SizedBox(height: 16),
            Text('All systems operational', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('USB Connection: Ready | Network: Standby', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}