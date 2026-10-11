/**
 * CLI Diagnostic Tool for Serial Ports & Windows COM Paths
 */
const { listAvailablePorts, normalizeComPort, KNOWN_CHIPSETS } = require('./port_scanner');

async function run() {
  console.log('======================================================');
  console.log('  Windows COM Port & USB Chipset Diagnostic Scanner   ');
  console.log('======================================================');

  console.log('\n[1] Testing Windows COM Path Normalization:');
  const testPorts = ['COM1', 'COM3', 'COM9', 'COM10', 'COM18', '\\\\.\\COM12', '/dev/ttyUSB0'];
  for (const tp of testPorts) {
    console.log(`    Input: ${tp.padEnd(14)} -> Normalized: ${normalizeComPort(tp)}`);
  }

  console.log('\n[2] Scanning Available System Ports:');
  try {
    const ports = await listAvailablePorts();
    if (!ports || ports.length === 0) {
      console.log('    No active serial ports detected.');
      console.log('    Supported chipsets: ' + KNOWN_CHIPSETS.map(c => c.name).join(', '));
    } else {
      console.log(`    Found ${ports.length} port(s):`);
      for (const p of ports) {
        console.log(`    - ${p.port} (${p.hardwarePath}): ${p.chipset} [${p.manufacturer}] via ${p.source}`);
      }
    }
  } catch (err) {
    console.error(`    Scan failed: ${err.message}`);
  }

  console.log('\n======================================================');
}

run();

