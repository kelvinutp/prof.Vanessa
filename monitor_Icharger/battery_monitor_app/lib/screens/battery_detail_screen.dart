import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/battery_state.dart';
import '../services/server_service.dart';
import '../services/serial_service.dart';

class BatteryDetailScreen extends StatefulWidget {
  final String batteryId;
  final bool isDesktop;
  final String? backendUrl;
  final String? authToken;

  const BatteryDetailScreen({
    super.key,
    required this.batteryId,
    required this.isDesktop,
    this.backendUrl,
    this.authToken,
  });

  @override
  State<BatteryDetailScreen> createState() => _BatteryDetailScreenState();
}

class _BatteryDetailScreenState extends State<BatteryDetailScreen> {
  BatteryInfo? battery;
  List<String> terminalLines = [];
  Timer? _timer;
  final ScrollController _terminalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _terminalScroll.dispose();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (widget.isDesktop) {
        final b = LocalServerService.currentBatteries[widget.batteryId];
        final logs = SerialService.getTerminalLogs(widget.batteryId);
        if (mounted) {
          setState(() {
            battery = b;
            terminalLines = List.from(logs);
          });
          _scrollToBottom();
        }
      } else {
        await _fetchRemote();
      }
    });
  }

  Future<void> _fetchRemote() async {
    if (widget.backendUrl == null || widget.authToken == null) return;
    final base = 'http://${widget.backendUrl}';
    final headers = {'Authorization': 'Bearer ${widget.authToken}'};
    try {
      final bMap = await _httpGet('$base/batteries', headers) as Map<String, dynamic>?;
      final lList = await _httpGet('$base/logs/${widget.batteryId}', headers) as List<dynamic>?;
      if (mounted) {
        setState(() {
          if (bMap != null && bMap.containsKey(widget.batteryId)) {
            battery = BatteryInfo.fromJson(bMap[widget.batteryId]);
          }
          if (lList != null) terminalLines = lList.cast<String>();
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<dynamic> _httpGet(String url, Map<String, String> headers) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      headers.forEach((k, v) => req.headers.add(k, v));
      final resp = await req.close();
      final body = await resp.transform(const Utf8Decoder()).join();
      return jsonDecode(body);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScroll.hasClients) {
        _terminalScroll.animateTo(
          _terminalScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _stateColor(String? state) {
    switch (state) {
      case 'charging':    return Colors.green;
      case 'discharging': return Colors.redAccent;
      case 'rest':        return Colors.orange;
      case 'finished':    return Colors.blueAccent;
      default:            return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = battery;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: Text('Battery: ${b?.bateria ?? widget.batteryId}'),
        actions: [
          if (widget.isDesktop && b?.status == 'monitoring')
            TextButton.icon(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              label: const Text('Stop', style: TextStyle(color: Colors.red)),
              onPressed: () {
                SerialService.stopMonitoring(widget.batteryId);
                if (LocalServerService.currentBatteries.containsKey(widget.batteryId)) {
                  LocalServerService.currentBatteries[widget.batteryId]!.status = 'stopped';
                }
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: b == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Header Info Panel ──────────────────────────────────
                _buildHeader(b),
                const Divider(height: 1, thickness: 1, color: Colors.white12),
                // ── Terminal Label ─────────────────────────────────────
                Container(
                  color: const Color(0xFF0F0F1A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, size: 15, color: Colors.white38),
                      const SizedBox(width: 6),
                      const Text('Serial Terminal',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const Spacer(),
                      Text('${terminalLines.length} / 200 lines',
                          style: const TextStyle(color: Colors.white24, fontSize: 11)),
                    ],
                  ),
                ),
                // ── Terminal Output ────────────────────────────────────
                Expanded(
                  child: Container(
                    color: const Color(0xFF080810),
                    child: terminalLines.isEmpty
                        ? const Center(
                            child: Text('Waiting for serial data…',
                                style: TextStyle(color: Colors.white24)))
                        : ListView.builder(
                            controller: _terminalScroll,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            itemCount: terminalLines.length,
                            itemBuilder: (ctx, i) => _buildTerminalLine(terminalLines[i]),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(BatteryInfo b) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16213E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(b.bateria,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _stateColor(b.state),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(b.state.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              _chip('Voltage',  '${b.voltage} V',    Colors.cyanAccent),
              _chip('Current',  '${b.current} A',    Colors.amberAccent),
              _chip('Capacity', '${b.capacity} mAh', Colors.greenAccent),
              _chip('Cycle',    b.ciclo,              Colors.purpleAccent),
              _chip('Nom. Cap.', b.capacidad,         Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            children: [
              _meta(Icons.usb,          '${b.port} @ ${b.baudrate} baud'),
              _meta(Icons.folder_open,  b.folder.isEmpty ? '(current dir)' : b.folder),
              _meta(Icons.update,       b.lastUpdate.isEmpty ? '—' : b.lastUpdate),
              _meta(Icons.info_outline, 'Status: ${b.status}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildTerminalLine(String line) {
    Color color = const Color(0xFF00FF7F); // default green
    if (line.contains('error') || line.contains('Error') || line.contains('Unable')) {
      color = Colors.red[300]!;
    } else if (line.contains('***') || line.contains('FINISHED') || line.contains('finished')) {
      color = Colors.blue[300]!;
    } else if (line.contains('>>>') || line.contains('Cycle increment')) {
      color = Colors.amber[300]!;
    } else if (line.startsWith('[')) {
      color = Colors.white60; // timestamp notes
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: SelectableText(
        line,
        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: color),
      ),
    );
  }
}
