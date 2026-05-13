import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/session_provider.dart';
import '../../core/models/battery_session.dart';
import '../../core/models/serial_data.dart';
import '../../core/services/unified_logger_service.dart';
import '../widgets/battery_chart_widget.dart';
import '../widgets/manual_adjustment_panel.dart';
import '../../core/models/chart_type.dart';

class SessionAnalysisScreen extends StatelessWidget {
  final BatterySession? session;

  const SessionAnalysisScreen({super.key, this.session});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(session != null ? 'Analysis: ${session!.batteryName}' : 'Independent Analysis'),
        actions: [
          if (provider.zoomMinX != null)
            TextButton.icon(
              onPressed: provider.resetZoom,
              icon: const Icon(Icons.zoom_out_map),
              label: const Text('Reset Zoom'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Reference CSV',
            onPressed: () async {
              unifiedLogger.log('Clicked Import Reference CSV button', source: LogSource.ui);
              FilePickerResult? result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['csv'],
              );
              if (result != null && result.files.single.path != null) {
                // ignore: use_build_context_synchronously
                await context.read<SessionProvider>().importReferenceFile(result.files.single.path!);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Charts Section
          Expanded(
            flex: 4,
            child: Consumer<SessionProvider>(
              builder: (context, provider, child) {
                final List<SerialData> filteredData = [];
                
                // Helper to filter data by stage
                bool stageFilter(SerialData d) => provider.selectedStages.contains(d.state);

                // Add Live data if selected and session exists
                if (session != null && provider.selectedSources.contains('live')) {
                  filteredData.addAll(session!.dataHistory.where((d) => 
                    provider.selectedCycles.contains(d.cycleNumber) && stageFilter(d)
                  ));
                }
                
                // Add Reference data if selected
                for (var entry in provider.analysisDataSources.entries) {
                  if (provider.selectedSources.contains(entry.key)) {
                    filteredData.addAll(entry.value.where((d) => 
                      provider.selectedCycles.contains(d.cycleNumber) && stageFilter(d)
                    ));
                  }
                }

                return Column(
                  children: [
                    // Quick Stats Bar
                    _buildStatsBar(session),
                    
                    if (provider.visibleGraphs.contains(ChartType.voltage))
                      Expanded(
                        child: BatteryChartWidget(
                          data: filteredData,
                          type: ChartType.voltage,
                          title: 'Voltage (V)',
                          color: Colors.red,
                          minX: provider.zoomMinX,
                          maxX: provider.zoomMaxX,
                          onZoomChanged: provider.setZoom,
                        ),
                      ),
                    if (provider.visibleGraphs.contains(ChartType.current))
                      Expanded(
                        child: BatteryChartWidget(
                          data: filteredData,
                          type: ChartType.current,
                          title: 'Current (mA)',
                          color: Colors.green,
                          minX: provider.zoomMinX,
                          maxX: provider.zoomMaxX,
                          onZoomChanged: provider.setZoom,
                        ),
                      ),
                    if (provider.visibleGraphs.contains(ChartType.capacity))
                      Expanded(
                        child: BatteryChartWidget(
                          data: filteredData,
                          type: ChartType.capacity,
                          title: 'Capacity (mAh)',
                          color: Colors.blue,
                          minX: provider.zoomMinX,
                          maxX: provider.zoomMaxX,
                          onZoomChanged: provider.setZoom,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          // Manual Adjustment & Control Sidebar
          Expanded(
            flex: 1,
            child: ManualAdjustmentPanel(session: session),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(BatterySession? session) {
    if (session == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.orange.shade50,
        child: const Center(
          child: Text('Independent Analysis Mode - Live Capture Disabled', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Current Cycle', session.currentCycle.toString()),
          _statItem('Voltage', '${session.dataHistory.isNotEmpty ? session.dataHistory.last.voltageV.toStringAsFixed(3) : '0.000'} V'),
          _statItem('Current', '${session.dataHistory.isNotEmpty ? session.dataHistory.last.currentMA.toStringAsFixed(2) : '0.00'} A'),
          _statItem('Capacity', '${session.dataHistory.isNotEmpty ? session.dataHistory.last.capacityMAh : '0'} mAh'),
          _statItem('State', session.currentState.displayName),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
