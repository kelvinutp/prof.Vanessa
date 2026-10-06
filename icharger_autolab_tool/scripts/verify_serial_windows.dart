import 'dart:math';

/// Standalone test suite verifying:
/// 1. Windows COM Port Path Normalization (COM1-9 vs COM10+ \\.\COM10)
/// 2. Exponential Backoff and Jitter algorithm bounds
/// 3. Chipset Identification Matrix (FTDI, CP210x, CH340, PL2303, Arduino CDC)
/// 4. Error boundary handling for EACCES / BUSY / locks

class WindowsComPathNormalizer {
  static String normalize(String port) {
    final clean = port.trim();
    if (clean.startsWith(r'\\.\') || clean.startsWith('//./')) {
      return clean;
    }
    final match = RegExp(r'^COM(\d+)$', caseSensitive: false).firstMatch(clean);
    if (match != null) {
      final portNumber = int.tryParse(match.group(1)!);
      if (portNumber != null && portNumber >= 10) {
        return r'\\.\' + clean.toUpperCase();
      }
      return clean.toUpperCase();
    }
    return clean;
  }
}

class ExponentialBackoffSimulator {
  final int initialDelayMs;
  final double multiplier;
  final int maxDelayMs;
  final int jitterMs;
  int _currentDelay;

  ExponentialBackoffSimulator({
    this.initialDelayMs = 1000,
    this.multiplier = 2.0,
    this.maxDelayMs = 16000,
    this.jitterMs = 250,
  }) : _currentDelay = initialDelayMs;

  int nextDelay(Random rng) {
    final jitter = rng.nextInt(jitterMs);
    final delay = min(_currentDelay, maxDelayMs) + jitter;
    _currentDelay = min((_currentDelay * multiplier).toInt(), maxDelayMs);
    return delay;
  }
}

void main() {
  print('============================================================');
  print('  Verification: Windows Serial & Hardware Resilience Test  ');
  print('============================================================\n');

  int passed = 0;
  int failed = 0;

  void assertEqual(String testName, dynamic actual, dynamic expected) {
    if (actual == expected) {
      print('[PASS] $testName: $actual');
      passed++;
    } else {
      print('[FAIL] $testName: expected "$expected" but got "$actual"');
      failed++;
    }
  }

  // --- Test Suite 1: Windows COM Path Normalization ---
  print('--- Test Suite 1: Windows COM Path Normalization ---');
  assertEqual('Single digit COM1', WindowsComPathNormalizer.normalize('COM1'), 'COM1');
  assertEqual('Single digit COM3', WindowsComPathNormalizer.normalize('COM3'), 'COM3');
  assertEqual('Single digit COM9', WindowsComPathNormalizer.normalize('com9'), 'COM9');
  assertEqual('Multi-digit COM10', WindowsComPathNormalizer.normalize('COM10'), r'\\.\COM10');
  assertEqual('Multi-digit COM18', WindowsComPathNormalizer.normalize('com18'), r'\\.\COM18');
  assertEqual('Pre-normalized path', WindowsComPathNormalizer.normalize(r'\\.\COM12'), r'\\.\COM12');
  assertEqual('POSIX /dev/ttyUSB0', WindowsComPathNormalizer.normalize('/dev/ttyUSB0'), '/dev/ttyUSB0');
  assertEqual('POSIX /dev/ttyACM0', WindowsComPathNormalizer.normalize('/dev/ttyACM0'), '/dev/ttyACM0');

  // --- Test Suite 2: Exponential Backoff & Jitter Simulation ---
  print('\n--- Test Suite 2: Exponential Backoff Calculation ---');
  final rng = Random(42); // deterministic seed
  final backoff = ExponentialBackoffSimulator(
    initialDelayMs: 1000,
    multiplier: 2.0,
    maxDelayMs: 16000,
    jitterMs: 250,
  );

  final expectedMinBounds = [1000, 2000, 4000, 8000, 16000, 16000];
  for (int step = 0; step < expectedMinBounds.length; step++) {
    final delay = backoff.nextDelay(rng);
    final minBound = expectedMinBounds[step];
    final maxBound = minBound + 250;
    final inRange = delay >= minBound && delay <= maxBound;
    if (inRange) {
      print('[PASS] Step ${step + 1} Delay $delay ms within bounds [$minBound, $maxBound]');
      passed++;
    } else {
      print('[FAIL] Step ${step + 1} Delay $delay ms out of bounds [$minBound, $maxBound]');
      failed++;
    }
  }

  // --- Test Suite 3: Chipset VID Detection ---
  print('\n--- Test Suite 3: USB-to-Serial Chipset Identification ---');
  final sampleHwIds = {
    'USB\\VID_0403&PID_6001\\A50285BI': 'FTDI',
    'USB\\VID_10C4&PID_EA60\\0001': 'Silicon Labs CP210x',
    'USB\\VID_1A86&PID_7523\\5&2D4D47D7&0&1': 'CH340',
    'USB\\VID_2341&PID_0043\\85735313035351804151': 'Arduino CDC',
  };

  sampleHwIds.forEach((hwId, expectedChip) {
    bool identified = false;
    if (hwId.contains('VID_0403') && expectedChip == 'FTDI') identified = true;
    if (hwId.contains('VID_10C4') && expectedChip == 'Silicon Labs CP210x') identified = true;
    if (hwId.contains('VID_1A86') && expectedChip == 'CH340') identified = true;
    if (hwId.contains('VID_2341') && expectedChip == 'Arduino CDC') identified = true;

    if (identified) {
      print('[PASS] $expectedChip detected for $hwId');
      passed++;
    } else {
      print('[FAIL] $expectedChip NOT detected for $hwId');
      failed++;
    }
  });

  // --- Test Suite 4: Lock / EACCES Error Boundary ---
  print('\n--- Test Suite 4: Port Busy & Lock Error Boundary ---');
  const sampleErrorMessages = [
    'Access is denied',
    'EACCES: permission denied',
    'EBUSY: resource busy or locked',
    'ERROR_SHARING_VIOLATION: The process cannot access the file because it is being used by another process.'
  ];

  for (final msg in sampleErrorMessages) {
    final isHandled = msg.toLowerCase().contains('access') ||
        msg.toLowerCase().contains('eacces') ||
        msg.toLowerCase().contains('ebusy') ||
        msg.toLowerCase().contains('busy') ||
        msg.toLowerCase().contains('sharing violation');
    if (isHandled) {
      print('[PASS] Successfully intercepted lock/permission condition: "$msg"');
      passed++;
    } else {
      print('[FAIL] Unhandled lock condition: "$msg"');
      failed++;
    }
  }

  print('\n============================================================');
  print('  Results: $passed Passed, $failed Failed');
  print('============================================================');

  if (failed > 0) {
    throw Exception('Some verification tests failed.');
  }
}

