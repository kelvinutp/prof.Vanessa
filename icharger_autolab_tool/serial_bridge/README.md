# Lab Control Suite - Serial to WebSocket Bridge

This service handles low-level Windows COM port communication (FTDI, QinHeng CH340, Silicon Labs CP210x, Prolific PL2303, Arduino CDC) and bridges telemetry in real-time over WebSocket to the Flutter Lab Control Suite application.

## Features
- **Multi-Digit COM Normalization**: Automatically transforms `COM10+` into Win32 device namespace (`\\.\COM10`) required by Windows.
- **Exponential Backoff Reconnection**: Gracefully handles USB disconnects/unplugs and automatically attempts reconnection with configurable delays and jitter.
- **Lock / Permission Boundaries**: Intercepts `EACCES` and `EBUSY` when a port is held by another process without crashing the service.
- **Safe Handle Cleanup**: Traps `SIGINT`, `SIGTERM`, and process exit to flush and release all Windows serial port handles.

## Setup & Installation

### Prerequisites
1. **Node.js** (v18+ recommended)
2. **Windows C++ Build Tools** (if compiling `@serialport/bindings-cpp` from source):
   ```cmd
   npm install --global windows-build-tools
   ```
   Or install Visual Studio Community / Build Tools with the "Desktop development with C++" workload.

### Installation
```cmd
cd serial_bridge
npm install
```

### Diagnostics
Run pre-flight checks:
```cmd
npm run check-env
npm run diagnose
```

### Running the Bridge
```cmd
npm start
```
By default, the bridge listens on `ws://127.0.0.1:8080`.

## Connecting with Flutter App
In the Flutter app, open the **Cross-Network Client/Server** screen or configure `NetworkService` to point to:
`ws://127.0.0.1:8080`
All serial telemetry received from the connected COM port will stream live directly to your Flutter graphs, CSV loggers, and voltage monitors.

