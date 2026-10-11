/**
 * Main Entry Point: Serial-to-WebSocket Bridge
 * Connects Windows COM ports to the Flutter Lab Control Suite via WebSocket.
 */
require('dotenv').config();
const http = require('http');
const { WebSocketServer } = require('ws');
const SerialManager = require('./serial_manager');
const { listAvailablePorts, normalizeComPort } = require('./port_scanner');
const path = require('path');
const fs = require('fs');

// Load configurations
let config = {};
const configPath = path.resolve(__dirname, '..', 'config', 'serial_config.json');
if (fs.existsSync(configPath)) {
  try {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch (e) {
    console.warn('[WARN] Failed to parse config/serial_config.json, using defaults.');
  }
}

const WS_PORT = process.env.WS_BRIDGE_PORT || (config.bridge && config.bridge.websocket_port) || 8080;
const WS_HOST = process.env.WS_BRIDGE_HOST || (config.bridge && config.bridge.websocket_host) || '127.0.0.1';
const DEFAULT_BAUD = parseInt(process.env.SERIAL_DEFAULT_BAUD || (config.serial && config.serial.default_baud_rate) || 115200, 10);
const DEFAULT_PORT = process.env.SERIAL_DEFAULT_PORT || null;

console.log('======================================================');
console.log('   Lab Control Suite - Serial to WebSocket Bridge    ');
console.log('======================================================');

const serialManager = new SerialManager({
  port: DEFAULT_PORT,
  baudRate: DEFAULT_BAUD,
  autoReconnect: process.env.SERIAL_AUTO_RECONNECT !== 'false',
  initialDelayMs: parseInt(process.env.SERIAL_INITIAL_DELAY_MS || 1000, 10),
  maxDelayMs: parseInt(process.env.SERIAL_MAX_DELAY_MS || 16000, 10),
  maxRetries: parseInt(process.env.SERIAL_MAX_RECONNECT_RETRIES || 20, 10)
});

// Create WebSocket Server
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'active', service: 'serial_bridge', serial_status: serialManager.status }));
});

const wss = new WebSocketServer({ server });

function broadcast(eventType, payload) {
  const msg = JSON.stringify({ event: eventType, timestamp: new Date().toISOString(), payload });
  for (const client of wss.clients) {
    if (client.readyState === 1) { // OPEN
      client.send(msg);
    }
  }
}

// Bind Serial Events to WebSocket Broadcasts
serialManager.on('status_change', (info) => {
  console.log(`[STATUS] ${info.status}: ${info.message}`);
  broadcast('serial_status', info);
});

serialManager.on('connected', (info) => {
  console.log(`[CONNECTED] COM Port Open: ${info.port} (Hardware path: ${info.hardwarePath}) @ ${info.baudRate} baud`);
  broadcast('serial_connected', info);
});

serialManager.on('data', (text) => {
  broadcast('telemetry_data', { raw: text });
});

serialManager.on('error', (err) => {
  console.error(`[ERROR] Serial exception: ${err.message}`);
  broadcast('serial_error', { message: err.message, code: err.code });
});

serialManager.on('disconnected', (info) => {
  console.log(`[DISCONNECTED] ${info.port} disconnected. Unexpected: ${info.unexpected}`);
  broadcast('serial_disconnected', info);
});

// WebSocket Client Message Handlers
wss.on('connection', async (ws, req) => {
  console.log(`[WS] New client connected from ${req.socket.remoteAddress}`);

  // Send initial handshake state
  ws.send(JSON.stringify({
    event: 'handshake',
    status: serialManager.status,
    activePort: serialManager.targetPort,
    baudRate: serialManager.baudRate
  }));

  ws.on('message', async (message) => {
    try {
      const text = message.toString();
      console.log(`[WS-IN] Received: ${text}`);

      let parsed;
      try {
        parsed = JSON.parse(text);
      } catch {
        parsed = { command: text };
      }

      const cmd = (parsed.command || parsed.action || '').toUpperCase();

      if (cmd === 'SCAN_PORTS' || cmd === 'LIST_PORTS') {
        const ports = await listAvailablePorts();
        ws.send(JSON.stringify({ event: 'ports_list', ports }));
      } else if (cmd === 'CONNECT' || cmd === 'CONNECT_PORT') {
        const port = parsed.port || parsed.targetPort;
        const baud = parsed.baudRate || DEFAULT_BAUD;
        serialManager.connect(port, baud);
      } else if (cmd === 'DISCONNECT') {
        serialManager.disconnect();
      } else if (cmd === 'PING' || cmd === 'PING_TELEMETRY') {
        ws.send(JSON.stringify({ event: 'pong', time: Date.now(), serial_status: serialManager.status }));
      } else if (cmd === 'WRITE' || cmd === 'SEND_SERIAL') {
        if (parsed.data) {
          const success = serialManager.write(parsed.data);
          ws.send(JSON.stringify({ event: 'write_result', success }));
        }
      }
    } catch (err) {
      ws.send(JSON.stringify({ event: 'error', message: err.message }));
    }
  });

  ws.on('close', () => {
    console.log('[WS] Client disconnected.');
  });
});

// Graceful Process Termination Cleanup
function cleanupAndExit(signal) {
  console.log(`\n[EXIT] Received ${signal}. Flushing handles and closing connections...`);
  serialManager.disconnect();
  wss.close(() => {
    server.close(() => {
      console.log('[EXIT] All handles released cleanly. Safe exit.');
      process.exit(0);
    });
  });
  // Force exit after 3 seconds if hanging
  setTimeout(() => process.exit(0), 3000);
}

process.on('SIGINT', () => cleanupAndExit('SIGINT'));
process.on('SIGTERM', () => cleanupAndExit('SIGTERM'));
process.on('uncaughtException', (err) => {
  console.error('[UNCAUGHT EXCEPTION]', err);
  // Do not crash on transient serial unplug or permission errors
});

// Start Server
server.listen(WS_PORT, WS_HOST, () => {
  console.log(`[SERVER] WebSocket Bridge listening on ws://${WS_HOST}:${WS_PORT}`);
  console.log(`[CONFIG] Default Baud: ${DEFAULT_BAUD} | Auto-Reconnect: ${serialManager.autoReconnect}`);
  if (DEFAULT_PORT) {
    console.log(`[AUTO-CONNECT] Attempting initial connection to ${DEFAULT_PORT}...`);
    serialManager.connect(DEFAULT_PORT, DEFAULT_BAUD);
  }
});

