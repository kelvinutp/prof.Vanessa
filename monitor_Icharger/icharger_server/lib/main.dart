import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/session_provider.dart';
import 'providers/auth_provider.dart';
import 'ui/screens/dashboard_screen.dart';
import 'core/services/unified_logger_service.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await unifiedLogger.initialize();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unifiedLogger.log(
          'FLUTTER ERROR: ${details.exceptionAsString()}',
          source: LogSource.crash,
        );
      };

      runApp(
        ChangeNotifierProvider(
          create: (_) => SessionProvider(),
          child: const IChargerApp(),
        ),
      );
    },
    (error, stack) {
      unifiedLogger.log(
        'UNCAUGHT ERROR: $error\nSTACKTRACE: $stack',
        source: LogSource.crash,
      );
    },
  );
}

class IChargerApp extends StatelessWidget {
  const IChargerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'ICharger Logger Server',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
      navigatorObservers: [ActivityNavigatorObserver()],
    );
  }
}

class ActivityNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    final screenName = route.settings.name ?? 'Dashboard';
    unifiedLogger.updateContext(screen: screenName);
    unifiedLogger.log('Navigated to $screenName', source: LogSource.ui);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    final screenName = previousRoute?.settings.name ?? 'Dashboard';
    unifiedLogger.updateContext(screen: screenName);
    unifiedLogger.log('Returned to $screenName', source: LogSource.ui);
  }
}
