enum BatteryState {
  charging,
  discharging,
  rest,
  finished,
  unknown;

  static BatteryState fromId(String id) {
    final cleanId = id.trim().toLowerCase();
    switch (cleanId) {
      case '1':
      case 'charging':
        return BatteryState.charging;
      case '2':
      case 'discharging':
        return BatteryState.discharging;
      case '4':
      case 'rest':
      case 'resting':
        return BatteryState.rest;
      case '6':
      case 'finished':
        return BatteryState.finished;
      default:
        return BatteryState.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.rest:
        return 'Rest';
      case BatteryState.finished:
        return 'Finished';
      case BatteryState.unknown:
        return 'Unknown';
    }
  }
}
