# prompts for LLM
## Sept 14,
```
{
  "project_context": {
    "app_name": "Lab Control Suite & iCharger",
    "framework": "Flutter",
    "architecture": "Provider pattern state management, multi-screen drawer navigation, cross-platform support (Windows, macOS, Linux)",
    "dependencies": {
      "usb_serial": "^0.5.2",
      "web_socket_channel": "^3.0.1",
      "provider": "^6.1.2",
      "path_provider": "^2.1.2"
    }
  },
  "screens_implemented": [
    {
      "name": "iCharger Screen",
      "features": ["USB port selection", "Baud rate configuration", "Live voltage monitoring display"]
    },
    {
      "name": "iCharger Cycling Screen",
      "features": ["USB port & baud rate configuration", "Battery information inputs (Name, Nominal Voltage, Capacity in mAh)", "Data collection & real-time export of all incoming serial telemetry to local CSV files using path_provider"]
    },
    {
      "name": "Autolab Screen",
      "features": ["Configuration form for Current Range", "Bandwidth of EI", "Setpoint DC", "DSG Input", "Wave Signal", "Number of Cycles", "Integration Time", "Frequency Sweep"]
    },
    {
      "name": "Network Screen",
      "features": ["WebSocket-based client-server connection handling for communication across different networks"]
    },
    {
      "name": "Timer Screen",
      "features": ["Configurable countdown timer (default 10 mins with preset options & custom duration input)"]
    },
    {
      "name": "System Status Screen",
      "features": ["Operational status and hardware diagnostics display"]
    }
  ],
  "utilities": {
    "setup_script": "setup_check.py (cross-platform Python pre-flight script checking Flutter SDK, Dart SDK, Git, and running automated 'flutter pub get')"
  },
  "current_status": "Awaiting third-party feedback before entering the next testing and development stage."
}
```