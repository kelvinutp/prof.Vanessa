/**
 * Environment & Native Dependency Diagnostics
 * Checks Node version, architecture, node-gyp, and Windows C++ build tools
 */
const os = require('os');
const { execSync } = require('child_process');

console.log('======================================================');
console.log('  Native Build & SerialPort Dependency Diagnostics    ');
console.log('======================================================');

const platform = os.platform();
const arch = os.arch();
console.log(`OS Platform     : ${platform}`);
console.log(`Architecture    : ${arch} (${arch === 'x64' ? '64-bit Windows' : arch})`);
console.log(`Node.js Version : ${process.version}`);

if (platform !== 'win32') {
  console.log('[INFO] Running on non-Windows environment.');
} else {
  console.log('[INFO] Windows detected. Checking COM port prerequisites...');
}

// 1. Check node-gyp
try {
  const gypVersion = execSync('npx --no-install node-gyp --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }).trim();
  console.log(`[OK] node-gyp available (version: ${gypVersion})`);
} catch (e) {
  console.log('[WARN] node-gyp is not globally installed. npm will use the local or bundled version during install.');
}

// 2. Check for Visual Studio C++ Build Tools
if (platform === 'win32') {
  const vsWhere = 'C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe';
  const fs = require('fs');
  if (fs.existsSync(vsWhere)) {
    try {
      const vsInfo = execSync(`"${vsWhere}" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName`, { encoding: 'utf8' }).trim();
      if (vsInfo) {
        console.log(`[OK] Visual C++ Build Tools detected: ${vsInfo}`);
      } else {
        console.log('[WARN] Visual Studio found, but C++ desktop build tools (VC.Tools.x86.x64) may be missing.');
      }
    } catch {
      console.log('[WARN] Could not query vswhere.exe.');
    }
  } else {
    console.log('[INFO] Prebuilt binary packages (@serialport/bindings-cpp) will be used if compilation tools are absent.');
  }
}

console.log('======================================================');
console.log('Diagnostics Complete.');

