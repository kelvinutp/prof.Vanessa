import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogSource {
  ui,
  system,
  mqtt,
  serial,
  crash,
}

class UnifiedLoggerService {
  static final UnifiedLoggerService _instance = UnifiedLoggerService._internal();
  factory UnifiedLoggerService() => _instance;
  UnifiedLoggerService._internal();

  File? _logFile;
  final String _userId = Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? 'unknown_user';
  
  String _currentScreen = 'Startup';
  String _currentTab = 'None';

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final logDir = Directory(p.join(appDocDir.path, 'logs', 'unified'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      _logFile = File(p.join(logDir.path, 'icharger_unified_log_$timestamp.csv'));

      if (!await _logFile!.exists()) {
        await _logFile!.writeAsString(
          'timestamp;userId;screen;tab;source;action\n',
          mode: FileMode.write,
        );
      }
      
      final logPath = _logFile!.path;
      print('\n' + '='*80);
      print('>>> UNIFIED LOG INITIALIZED AT: $logPath');
      print('='*80 + '\n');
      
      log('Application Started', source: LogSource.system);
    } catch (e) {
      debugPrint('Error initializing unified logger: $e');
    }
  }

  void updateContext({String? screen, String? tab}) {
    if (screen != null) _currentScreen = screen;
    if (tab != null) _currentTab = tab;
  }

  void log(String action, {LogSource source = LogSource.system, String? screen, String? tab}) {
    final timestamp = DateTime.now().toIso8601String();
    final sourceStr = source.toString().split('.').last.toUpperCase();
    final currentScreen = screen ?? _currentScreen;
    final currentTab = tab ?? _currentTab;

    // Sanitize action to avoid CSV breakages (remove semicolons and newlines)
    final sanitizedAction = action.replaceAll(';', ',').replaceAll('\n', ' ').replaceAll('\r', ' ');
    
    final row = '$timestamp;$_userId;$currentScreen;$currentTab;$sourceStr;$sanitizedAction\n';
    
    if (kDebugMode) {
      print('[$sourceStr] $sanitizedAction');
    }
    
    if (_logFile != null) {
      _logFile!.writeAsStringSync(row, mode: FileMode.append);
    }
  }

  void shutdown() {
    log('Application Shutting Down', source: LogSource.system);
    if (_logFile != null) {
      print('\n' + '='*80);
      print('>>> FINAL UNIFIED LOG SAVED AT: ${_logFile!.path}');
      print('='*80 + '\n');
    }
  }
}

final unifiedLogger = UnifiedLoggerService();
