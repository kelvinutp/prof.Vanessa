import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/client_provider.dart';
import 'providers/auth_provider.dart';
import 'ui/screens/client_dashboard_screen.dart';
import 'ui/screens/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
      ],
      child: const IChargerClientApp(),
    ),
  );
}

class IChargerClientApp extends StatelessWidget {
  const IChargerClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return MaterialApp(
      title: 'ICharger Remote Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: authProvider.isAuthenticated
          ? const ClientDashboardScreen()
          : const LoginScreen(),
    );
  }
}
