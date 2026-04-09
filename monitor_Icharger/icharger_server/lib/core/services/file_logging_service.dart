import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/battery_session.dart';
import '../models/serial_data.dart';

class FileLoggingService {
  Future<String> getDefaultSavePath() async {
    if (Platform.isWindows || Platform.isLinux) {
      final desktopDir = Directory('${Platform.environment['HOME']}/Desktop'); // Simplistic for now, might need more robust path_provider usage
      if (await desktopDir.exists()) return desktopDir.path;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    return appDocDir.path;
  }

  Future<void> initializeSessionFiles(BatterySession session) async {
    final folder = Directory(session.savePath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final rawFile = File(p.join(session.savePath, _getRawFileName(session)));
    if (!await rawFile.exists()) {
      await rawFile.writeAsString(
        'date;system_time;cycle_time;cycle_number;data starting;cycle;empty;'
        'provided voltage;voltage (mV);current (cA);battery1;battery2;'
        'battery3;battery4;battery5;battery6;unknown0;unknown1;capacity (mAh);unknown2\n'
      );
    }
  }

  Future<void> logData(BatterySession session, SerialData data) async {
    // Log to raw file
    final rawFile = File(p.join(session.savePath, _getRawFileName(session)));
    await rawFile.writeAsString('${data.rawLine}\n', mode: FileMode.append);

    // Log to state-specific file
    final stateFile = File(p.join(session.savePath, _getStateFileName(session, data)));
    if (!await stateFile.exists()) {
      await stateFile.writeAsString(
        'date;system_time;cycle_time;cycle_number;battery_state;voltage[V];current[mA];capacity[mAh]\n'
      );
    }
    await stateFile.writeAsString('${data.toCsvRow(';')}\n', mode: FileMode.append);
  }

  String _getRawFileName(BatterySession session) {
    return 'data_original_${session.batteryName}_${session.nominalCapacity}_${session.startingCycle}.csv';
  }

  String _getStateFileName(BatterySession session, SerialData data) {
    return '${session.batteryName}${data.state.name}_${session.nominalCapacity}_${session.startingCycle}.csv';
  }
}
