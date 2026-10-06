/**
 * Resilient Serial Connection Manager
 * Features:
 * - Exponential backoff auto-reconnection
 * - Windows COM path normalization (COM10+ handling)
 * - Safe error boundaries for EACCES / EBUSY / unplug events
 * - Clean event listener and handle cleanup
 */
const EventEmitter = require('events');
const { normalizeComPort } = require('./port_scanner');

class SerialManager extends EventEmitter {
  constructor(config = {}) {
    super();
    this.targetPort = config.port || null;
    this.baudRate = config.baudRate || 115200;
    this.autoReconnect = config.autoReconnect !== false;
    this.initialDelayMs = config.initialDelayMs || 1000;
    this.multiplier = config.multiplier || 2.0;
    this.maxDelayMs = config.maxDelayMs || 16000;
    this.jitterMs = config.jitterMs || 250;
    this.maxRetries = config.maxRetries || 20;

    this.currentDelay = this.initialDelayMs;
    this.retryCount = 0;
    this.reconnectTimer = null;
    this.portInstance = null;
    this.status = 'DISCONNECTED'; // DISCONNECTED, CONNECTING, CONNECTED, RECONNECTING, BUSY, ERROR
    this.isExplicitClose = false;
  }

  calculateBackoff() {
    const jitter = Math.floor(Math.random() * this.jitterMs);
    const delay = Math.min(this.currentDelay, this.maxDelayMs) + jitter;
    this.currentDelay = Math.min(this.currentDelay * this.multiplier, this.maxDelayMs);
    return delay;
  }

  async connect(portName, baudRate) {
    if (portName) this.targetPort = portName;
    if (baudRate) this.baudRate = baudRate;

    if (!this.targetPort) {
      this.emitError(new Error('No target COM port specified for connection.'));
      return;
    }

    this.isExplicitClose = false;
    this.setStatus('CONNECTING', `Connecting to ${this.targetPort} @ ${this.baudRate} baud...`);

    const formattedPath = normalizeComPort(this.targetPort);

    try {
      let SerialPort;
      try {
        SerialPort = require('serialport').SerialPort;
      } catch (e) {
        throw new Error(`SerialPort native bindings not available. Run 'npm install' in serial_bridge. Details: ${e.message}`);
      }

      this.cleanupPort();

      this.portInstance = new SerialPort({
        path: formattedPath,
        baudRate: this.baudRate,
        autoOpen: false,
        dataBits: 8,
        stopBits: 1,
        parity: 'none'
      });

      this.portInstance.on('open', () => {
        this.status = 'CONNECTED';
        this.retryCount = 0;
        this.currentDelay = this.initialDelayMs;
        this.emit('connected', {
          port: this.targetPort,
          hardwarePath: formattedPath,
          baudRate: this.baudRate
        });
      });

      this.portInstance.on('data', (data) => {
        const text = data.toString('utf8');
        this.emit('data', text, data);
      });

      this.portInstance.on('error', (err) => {
        this.handlePortError(err);
      });

      this.portInstance.on('close', () => {
        if (!this.isExplicitClose) {
          this.handleUnexpectedClose();
        } else {
          this.setStatus('DISCONNECTED', 'Port closed manually.');
        }
      });

      // Attempt open
      this.portInstance.open((err) => {
        if (err) {
          this.handlePortError(err);
        }
      });

    } catch (err) {
      this.handlePortError(err);
    }
  }

  handlePortError(err) {
    const message = err ? err.message : 'Unknown serial error';
    const code = err ? err.code : '';

    // Check for Access Denied or Port Locked by another process
    if (code === 'EACCES' || code === 'EBUSY' || message.includes('Access is denied') || message.includes('File not found')) {
      this.setStatus('BUSY', `Device access error: ${message}. Ensure no other app (e.g. Putty, Arduino IDE, or another terminal) is holding the port.`);
    } else {
      this.setStatus('ERROR', `Serial error: ${message}`);
    }

    this.emit('error', err);

    if (this.autoReconnect && !this.isExplicitClose) {
      this.scheduleReconnect();
    }
  }

  handleUnexpectedClose() {
    this.setStatus('RECONNECTING', `Connection to ${this.targetPort} lost (device unplugged or closed).`);
    this.emit('disconnected', { port: this.targetPort, unexpected: true });

    if (this.autoReconnect && !this.isExplicitClose) {
      this.scheduleReconnect();
    }
  }

  scheduleReconnect() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (this.retryCount >= this.maxRetries) {
      this.setStatus('DISCONNECTED', `Max reconnect retries (${this.maxRetries}) reached. Stopped.`);
      this.emit('reconnect_failed', { port: this.targetPort, retries: this.retryCount });
      return;
    }

    const delay = this.calculateBackoff();
    this.retryCount++;
    this.setStatus('RECONNECTING', `Attempting auto-reconnect #${this.retryCount} in ${Math.round(delay)}ms...`);

    this.reconnectTimer = setTimeout(() => {
      this.connect();
    }, delay);
  }

  disconnect() {
    this.isExplicitClose = true;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.cleanupPort();
    this.setStatus('DISCONNECTED', 'Disconnected by user.');
    this.emit('disconnected', { port: this.targetPort, unexpected: false });
  }

  cleanupPort() {
    if (this.portInstance) {
      try {
        this.portInstance.removeAllListeners();
        if (this.portInstance.isOpen) {
          this.portInstance.close();
        }
      } catch (e) {
        // Safe disposal
      }
      this.portInstance = null;
    }
  }

  setStatus(status, message) {
    this.status = status;
    this.emit('status_change', { status, message });
  }

  emitError(err) {
    this.emit('error', err);
  }

  write(payload) {
    if (this.portInstance && this.portInstance.isOpen) {
      this.portInstance.write(payload);
      return true;
    }
    return false;
  }
}

module.exports = SerialManager;

