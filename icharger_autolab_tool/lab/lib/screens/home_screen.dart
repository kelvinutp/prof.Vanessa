import 'package:flutter/material.dart';
import 'icharger_screen.dart';
import 'icharger_cycling_screen.dart';
import 'autolab_screen.dart';
import 'network_screen.dart';
import 'timer_screen.dart';
import 'status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const IChargerScreen(),
    const IChargerCyclingScreen(),
    const AutolabScreen(),
    const NetworkScreen(),
    const TimerScreen(),
    const StatusScreen(),
  ];

  final List<String> _screenTitles = [
    'iCharger (Voltage & Port)',
    'iCharger Cycling & CSV Log',
    'Autolab Configuration',
    'Cross-Network Client/Server',
    'Timer & Countdown',
    'System Status',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_screenTitles[_currentIndex])),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.science, size: 48, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Lab Control Suite', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('iCharger (Basic)'),
              selected: _currentIndex == 0,
              onTap: () { setState(() => _currentIndex = 0); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.loop),
              title: const Text('iCharger Cycling & CSV'),
              selected: _currentIndex == 1,
              onTap: () { setState(() => _currentIndex = 1); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Autolab Setup'),
              selected: _currentIndex == 2,
              onTap: () { setState(() => _currentIndex = 2); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.lan),
              title: const Text('Network Server/Client'),
              selected: _currentIndex == 3,
              onTap: () { setState(() => _currentIndex = 3); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Timer (Configurable)'),
              selected: _currentIndex == 4,
              onTap: () { setState(() => _currentIndex = 4); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.monitor),
              title: const Text('System Status'),
              selected: _currentIndex == 5,
              onTap: () { setState(() => _currentIndex = 5); Navigator.pop(context); },
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
    );
  }
}