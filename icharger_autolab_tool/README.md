# commands
## for running from github codespace
# Lab Control Suite & iCharger Tool

Cross-platform laboratory automation and battery cycling telemetry tool supporting Windows Desktop, GitHub Codespaces (Flutter Web), and Android/Linux/macOS.

---

## 1. Quick Verification & Diagnostics

### Run Serial Hardware & Windows COM Diagnostic:
Checks active COM ports across Registry (`SERIALCOMM`), WMI/CIM, and PnP entities, recognizing FTDI, Silicon Labs CP210x, QinHeng CH340, Prolific PL2303, and Arduino CDC devices:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose_ports.ps1 -TestAccess
```
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0

### Run Automated Architecture & Resilience Verification:
Tests Windows COM path normalization (`COM1-9` vs `\\.\COM10+`), exponential backoff jitter bounds, chipset recognition, and `EACCES`/`BUSY` error boundaries:
```cmd
dart run scripts\verify_serial_windows.dart
```

## Windows
1. Testing flutter installation
---

## 2. Windows Desktop Execution

### Prerequisites:
```cmd
flutter --version
flutter config --enable-windows-desktop

```
If everything is ok, 

2. FLutter configuration

This commands ensures that all required Windows toolchains (like Visual Studio for C++ build tools) and project dependencies are fully satisfied.
Check overall environment health
### Health check & dependency fetch:
```cmd
flutter doctor
cd lab
flutter pub get
flutter analyze
flutter test
```

Once dependencies are verified and clean, they can launch the app locally on Windows.

3. **View available target devices:**
### Run Windows Desktop App:
```cmd
flutter devices
flutter run -d windows
```

---

## 3. GitHub Codespaces / Web Execution
To run in browser from a Codespace:
```bash
cd lab
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

---

*(They should see `windows` listed as a desktop device).*
## 4. Node.js Serial-to-WebSocket Bridge (Optional Headless Daemon)

4. **Run the application:**
When running Flutter on Web or in remote client-server setups, use the high-performance Node.js Serial Bridge located in `serial_bridge/`:

```cmd
flutter run -d windows
cd serial_bridge
npm install
npm run check-env
npm run diagnose
npm start
```
The bridge listens on `ws://127.0.0.1:8080` and streams serial telemetry directly to Flutter's `NetworkService`.

```
---

## 5. Configuration Files

- [`config/serial_config.json`](config/serial_config.json): Dynamic baud rates, exponential backoff timing, and known USB chipset matrix.
- [`.env.example`](.env.example): Environment variable templates for ports, bauds, and WebSocket servers.