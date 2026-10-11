/**
 * Port Scanner with Windows COM Normalization and Fallback Discovery
 */
const { execSync } = require('child_process');
const path = require('path');
const os = require('os');

const KNOWN_CHIPSETS = [
  { name: 'FTDI FT232 / FT2232', vid: '0403' },
  { name: 'Silicon Labs CP210x', vid: '10C4' },
  { name: 'WCH QinHeng CH340 / CH341', vid: '1A86' },
  { name: 'Prolific PL2303', vid: '067B' },
  { name: 'Arduino / Atmel CDC', vid: '2341' },
  { name: 'Arduino Uno / Mega CDC', vid: '2A03' },
  { name: 'Raspberry Pi Pico CDC', vid: '2E8A' },
  { name: 'STMicroelectronics VCP', vid: '0483' }
];

/**
 * Normalizes Windows COM ports to Win32 device namespace if port >= 10.
 * Single digit ports (COM1-COM9) can be opened as-is, but COM10+ requires \\.\COM10
 */
function normalizeComPort(portPath) {
  if (!portPath || typeof portPath !== 'string') return portPath;
  const clean = portPath.trim();

  // If already prefixed with \\.\ or //./, return as-is
  if (clean.startsWith('\\\\.\\') || clean.startsWith('//./')) {
    return clean;
  }

  // Check for COM10, COM11, etc.
  const match = clean.match(/^COM(\d+)$/i);
  if (match) {
    const num = parseInt(match[1], 10);
    if (num >= 10) {
      return `\\\\.\\${clean.toUpperCase()}`;
    }
    return clean.toUpperCase();
  }

  return clean;
}

/**
 * Identify manufacturer or chipset name from Vendor ID
 */
function identifyChipset(vid, friendlyName) {
  if (vid) {
    const normalizedVid = vid.replace(/^0x/i, '').toUpperCase().padStart(4, '0');
    const found = KNOWN_CHIPSETS.find(c => c.vid.toUpperCase() === normalizedVid);
    if (found) return found.name;
  }
  if (friendlyName) {
    for (const c of KNOWN_CHIPSETS) {
      if (friendlyName.toLowerCase().includes(c.name.toLowerCase().split(' ')[0])) {
        return c.name;
      }
    }
  }
  return 'Standard / Generic Serial Port';
}

/**
 * Enumerate ports using SerialPort package or fallback to PowerShell diagnostic
 */
async function listAvailablePorts() {
  // Method 1: Try SerialPort if available
  try {
    const { SerialPort } = require('serialport');
    const ports = await SerialPort.list();
    if (ports && ports.length > 0) {
      return ports.map(p => {
        const portName = p.path || p.pnpId || 'UNKNOWN';
        return {
          port: portName,
          hardwarePath: normalizeComPort(portName),
          manufacturer: p.manufacturer || 'Unknown',
          serialNumber: p.serialNumber || 'N/A',
          vendorId: p.vendorId || null,
          productId: p.productId || null,
          chipset: identifyChipset(p.vendorId, p.friendlyName || p.manufacturer),
          source: 'serialport'
        };
      });
    }
  } catch (err) {
    // SerialPort not installed or failed, proceed to fallback
  }

  // Method 2: Fallback on Windows via PowerShell diagnose_ports.ps1
  if (os.platform() === 'win32') {
    try {
      const scriptPath = path.resolve(__dirname, '..', 'scripts', 'diagnose_ports.ps1');
      const output = execSync(
        `powershell -ExecutionPolicy Bypass -Command "& { & '${scriptPath}' -AsJson }"`,
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
      ).trim();

      if (output) {
        const parsed = JSON.parse(output);
        const list = Array.isArray(parsed) ? parsed : [parsed];
        return list.map(item => ({
          port: item.PortName,
          hardwarePath: normalizeComPort(item.PortName),
          manufacturer: item.Manufacturer || 'Unknown',
          serialNumber: 'N/A',
          vendorId: null,
          productId: null,
          chipset: item.Chipset || 'Generic',
          source: 'powershell-wmi'
        }));
      }
    } catch (e) {
      // PowerShell fallback failed
    }
  }

  return [];
}

module.exports = {
  normalizeComPort,
  identifyChipset,
  listAvailablePorts,
  KNOWN_CHIPSETS
};

