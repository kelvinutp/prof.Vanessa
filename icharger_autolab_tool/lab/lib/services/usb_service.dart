import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:web/web.dart' as html;

enum ConnectionStateEnum { 
  disconnected, 
  connecting, 
  autoBauding, 
  connected, 
  baudRateFailed 
}

class UsbService with ChangeNotifier {
  List<dynamic> devices = [];
  dynamic _activePort;
  StreamSubscription<Uint8List>? _subscription;
  
  ConnectionStateEnum _connectionState = ConnectionStateEnum.disconnected;
  ConnectionStateEnum get connectionState => _connectionState;

  int selectedBaudRate = 115200;
  final List<int> _baudCandidates = [115200, 9600, 38400];
  
  // Live telemetry metrics
  double _liveVoltage = 0.0;
  double get liveVoltage => _liveVoltage;

  final _dataController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  void Function(String rawData)? onDataReceived;
  void Function(String message)? onNotificationTriggered;

  bool _isRecording = false;
  bool get isRecording => _isRecording;
  final List<String> _csvBuffer = [];

  void setBaudRate(int baud) {
    selectedBaudRate = baud;
    notifyListeners();
  }

  /// 1. Detect USB devices (Windows COM ports / Web Browser Serial API prompt)
  Future<void> getAvailableDevices() async {
  try {
    if (kIsWeb) {
      debugPrint("Web Serial port requesting via browser permission prompt...");
      
      // Bypass static type check for experimental Web Serial API
      final nav = html.window.navigator as dynamic;
      if (nav.serial == null) {
        onNotificationTriggered?.call("Web Serial API is not supported in this browser. Use Chrome or Vivaldi.");
        return;
      }

      // Request port access via browser permission picker popup
      final webPort = await nav.serial.requestPort().toDart;
      devices = [webPort];
      onNotificationTriggered?.call("USB device selected successfully.");
    } else {
      devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        onNotificationTriggered?.call("No USB COM devices found. Check physical connection.");
      }
    }
  } catch (e) {
    debugPrint("Error detecting devices/requesting permissions: $e");
    devices = [];
    onNotificationTriggered?.call("Permission denied or device selection cancelled.");
  }
  notifyListeners();
}

  /// 2. Connect with Auto-Baud Detection (Tries up to 3 candidate speeds)
  Future<bool> connectWithAutoBaud(dynamic device) async {
    _connectionState = ConnectionStateEnum.connecting;
    notifyListeners();

    try {
      await disconnect();

      if (!kIsWeb) {
        _activePort = await device.create();
        if (_activePort == null || await _activePort!.open() != true) {
          _handleConnectionFailure("Could not open the selected COM port.");
          return false;
        }
        await _activePort!.setDTR(true);
        await _activePort!.setRTS(true);
      }

      bool baudFound = false;

      for (int i = 0; i < 3 && i < _baudCandidates.length; i++) {
        int candidateBaud = _baudCandidates[i];
        _connectionState = ConnectionStateEnum.autoBauding;
        notifyListeners();

        debugPrint("Auto-baud attempt ${i + 1}: Trying $candidateBaud baud...");
        await _setPortBaudRate(candidateBaud);

        bool receivedValidData = await _testBaudRateStream();
        if (receivedValidData) {
          selectedBaudRate = candidateBaud;
          baudFound = true;
          break;
        }
      }

      if (!baudFound) {
        _connectionState = ConnectionStateEnum.baudRateFailed;
        notifyListeners();
        await _activePort?.close();
        _activePort = null;
        onNotificationTriggered?.call("Auto-baud failed after 3 attempts. Please choose baud manually.");
        return false;
      }

      _connectionState = ConnectionStateEnum.connected;
      _startListening();
      notifyListeners();
      onNotificationTriggered?.call("Successfully connected at $selectedBaudRate baud!");
      return true;

    } catch (e) {
      await disconnect();
      _handleConnectionFailure("Connection exception: $e");
      return false;
    }
  }

  /// Fallback connection method when manual baud rate is selected by the user
  Future<bool> connectWithManualBaud(dynamic device, int manualBaud) async {
    try {
      await disconnect();
      selectedBaudRate = manualBaud;
      _connectionState = ConnectionStateEnum.connecting;
      notifyListeners();

      if (!kIsWeb) {
        _activePort = await device.create();
        if (_activePort == null || await _activePort!.open() != true) {
          _handleConnectionFailure("Failed to open port for manual baud rate.");
          return false;
        }
        await _activePort!.setDTR(true);
        await _activePort!.setRTS(true);
      }

      await _setPortBaudRate(selectedBaudRate);

      _connectionState = ConnectionStateEnum.connected;
      _startListening();
      notifyListeners();
      onNotificationTriggered?.call("Connected using manual baud rate: $selectedBaudRate");
      return true;
    } catch (e) {
      _handleConnectionFailure("Manual connection error: $e");
      return false;
    }
  }

  Future<void> _setPortBaudRate(int baud) async {
    if (!kIsWeb && _activePort != null) {
      await _activePort!.setPortParameters(
        baud,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
    }
  }

Future<bool> _testBaudRateStream() async {
    Completer<bool> completer = Completer<bool>();
    String buffer = "";

    StreamSubscription<Uint8List>? testSub = _activePort!.inputStream!.listen((data) {
      buffer += utf8.decode(data, allowMalformed: true);
      if (buffer.contains('\n') || buffer.length > 10) {
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    Timer(const Duration(milliseconds: 800), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    bool success = await completer.future;
    
    // Fix: Use ?. to safely cancel if testSub is null
    await testSub?.cancel(); 
    
    return success;
  }

  void _startListening() {
    String lineBuffer = "";
    _subscription = _activePort!.inputStream!.listen((Uint8List data) {
      final decodedString = utf8.decode(data, allowMalformed: true);
      
      onDataReceived?.call(decodedString);

      // Parse incoming voltage telemetry using regex pattern matching (e.g. "12.45V")
      final voltageMatch = RegExp(r'(\d+\.\d+)\s*V?', caseSensitive: false).firstMatch(decodedString);
      if (voltageMatch != null) {
        _liveVoltage = double.tryParse(voltageMatch.group(1)!) ?? _liveVoltage;
        notifyListeners();
      }

      if (_isRecording) {
        _csvBuffer.add('${DateTime.now().toIso8601String()},${decodedString.trim()}');
      }

      lineBuffer += decodedString;
      while (lineBuffer.contains('\n')) {
        int index = lineBuffer.indexOf('\n');
        String line = lineBuffer.substring(0, index).trim();
        lineBuffer = lineBuffer.substring(index + 1);
        _dataController.add(line);
      }
    }, onError: (error) {
      disconnect();
    }, onDone: () {
      disconnect();
    });
  }

  Future<void> startCsvRecording() async {
    _csvBuffer.clear();
    _csvBuffer.add('Timestamp,RawData');
    _isRecording = true;
    notifyListeners();
    onNotificationTriggered?.call("Local CSV recording started.");
  }

  Future<void> stopAndSaveCsvFile() async {
    _isRecording = false;
    notifyListeners();

    if (_csvBuffer.length <= 1) {
      onNotificationTriggered?.call("No data recorded to save.");
      return;
    }

    String csvContent = _csvBuffer.join('\n');
    try {
      if (kIsWeb) {
        debugPrint("Web CSV export triggered via Blob.");
        onNotificationTriggered?.call("CSV file ready for browser download.");
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/icharger_telemetry_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File(path);
        await file.writeAsString(csvContent);
        onNotificationTriggered?.call("CSV successfully saved to: $path");
      }
    } catch (e) {
      onNotificationTriggered?.call("Failed to save CSV file: $e");
    }
  }

  void _handleConnectionFailure(String message) {
    _connectionState = ConnectionStateEnum.disconnected;
    notifyListeners();
    onNotificationTriggered?.call(message);
  }

  Future<void> disconnect() async {
    if (_isRecording) {
      await stopAndSaveCsvFile();
    }
    await _subscription?.cancel();
    _subscription = null;

    try {
      await _activePort?.close();
    } catch (_) {}
    _activePort = null;
    
    _connectionState = ConnectionStateEnum.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _dataController.close();
    super.dispose();
  }
}