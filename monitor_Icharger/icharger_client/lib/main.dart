import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/client_provider.dart';
import 'ui/screens/client_dashboard_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ClientProvider(),
      child: const IChargerClientApp(),
    ),
  );
}

class IChargerClientApp extends StatelessWidget {
  const IChargerClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICharger Remote Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ClientDashboardScreen(),
    );
  }
}
