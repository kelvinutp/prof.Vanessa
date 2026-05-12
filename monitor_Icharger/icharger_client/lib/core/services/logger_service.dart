import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final List<String> _logs = [];
  List<String> get logs => _logs;
  
  Function(String)? onLog;

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    debugPrint(logEntry);
    onLog?.call(logEntry);
    
    if (!kIsWeb) {
      _writeToFile(logEntry);
    }
  }

  Future<void> _writeToFile(String entry) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/client_icharger_logs.txt');
      await file.writeAsString('$entry\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Error writing to log file: $e');
    }
  }
  
  Future<String> getLogFilePath() async {
    if (kIsWeb) return 'Browser Console / localStorage';
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/client_icharger_logs.txt';
  }
}

final logger = LoggerService();
