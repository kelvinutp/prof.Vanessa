# ICharger Client Codespace Analysis

The `icharger_client` is a cross-platform Flutter application designed for remote visualization and monitoring of battery charging/discharging sessions within the **ICharger Multi-Battery Ecosystem**. It communicates with a central `icharger_server` via MQTT to provide real-time telemetry and historical data visualization.

---

## 🛠 Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** `provider`
- **Communication:** `mqtt_client` (MQTT over TCP)
- **Visualization:** `fl_chart`
- **Local Storage:** `shared_preferences`

---

## 📂 Project Structure

### `lib/core` (Core Logic)
- **`models/`**: Data structures for the application.
    - `battery_session.dart`: Represents a single charging/discharging session (metadata and history).
    - `battery_state.dart`: Enum and helpers for battery states (Charge, Discharge, Rest, Finish).
    - `serial_data.dart`: Parser for raw iCharger serial frames.
- **`services/`**: Infrastructure and external integrations.
    - `mqtt_client_service.dart`: Handles connection, subscription, and publishing to the MQTT broker (`test.mosquitto.org`).
- **`utils/`**: Helper functions.
    - `data_processor.dart`: Logic for processing incoming data points and maintaining session integrity.

### `lib/providers` (State Management)
- **`client_provider.dart`**: The central state manager. Handles the connection lifecycle, receives MQTT payloads, updates session models, and notifies the UI.

### `lib/ui` (Presentation Layer)
- **`screens/`**: Main page layouts.
    - `client_dashboard_screen.dart`: The primary interface featuring connection controls, session summaries, and real-time terminal/graph views.
- **`widgets/`**: Reusable UI components.
    - `graphing_panel.dart`: Encapsulates the `fl_chart` logic for displaying Voltage, Current, and Capacity trends.

---

## 🔄 Data Flow & Communication

1.  **Connection**: The user enters a `Server Code` in the UI.
2.  **MQTT Subscription**: `ClientProvider` initiates a connection via `MqttClientService` to `icharger/$serverCode`.
3.  **Telemetry Ingestion**: The server publishes JSON payloads (`session_update`, `data_point`) to the topic.
4.  **State Update**: `ClientProvider` parses these payloads, updates the relevant `BatterySession` object, and triggers a UI rebuild.
5.  **Visualization**: `GraphingPanel` consumes the session data to render live line charts.

---

## 📊 Message Protocol
The client listens for JSON-encoded MQTT messages:
- `type: "welcome"`: Initial handshake from server.
- `type: "status"`: Server connectivity status (e.g., "offline").
- `type: "session_update"`: Updates to session metadata (active status, battery type).
- `type: "data_point"`: Real-time telemetry containing current, voltage, and capacity.

---

## 🚀 Key Features
- **Remote Monitoring**: View battery status from anywhere via the MQTT bridge.
- **Real-time Graphing**: Dynamic line charts for performance analysis.
- **Terminal View**: Synchronized raw serial logs for low-level debugging.
- **Session Persistence**: Remembers the last used Server Code for quick reconnection.
