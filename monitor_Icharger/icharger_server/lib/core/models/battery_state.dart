enum BatteryState {
  charging,
  discharging,
  rest,
  finished,
  unknown;

  static BatteryState fromId(String id) {
    switch (id.trim()) {
      case '1':
        return BatteryState.charging;
      case '2':
        return BatteryState.discharging;
      case '4':
        return BatteryState.rest;
      case '6':
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
        return 'Resting';
      case BatteryState.finished:
        return 'Finished';
      case BatteryState.unknown:
        return 'Unknown';
    }
  }
}
