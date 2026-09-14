import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';

class UsbService with ChangeNotifier {
  List<UsbDevice> devices = [];
  UsbPort? _port;
  bool isConnected = false;
  int selectedBaudRate = 115200;
  double liveVoltage = 0.0;
  
  // Callback hook for external CSV logging
  void Function(String rawData)? onDataReceived;

  void setBaudRate(int baud) {
    selectedBaudRate = baud;
    notifyListeners();
  }

  Future<void> getAvailableDevices() async {
    devices = await UsbSerial.listDevices();
    notifyListeners();
  }

  Future<void> connect(UsbDevice device) async {
    _port = await device.create();
    if (await _port!.open() != true) {
      return;
    }
    isConnected = true;
    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(selectedBaudRate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    
    _port!.inputStream!.listen((Uint8List data) {
      final decodedString = utf8.decode(data, allowMalformed: true);
      
      if (onDataReceived != null) {
        onDataReceived!(decodedString);
      }

      liveVoltage = 3.250; 
      notifyListeners();
    });
    notifyListeners();
  }
}