import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/session_provider.dart';
import '../../core/models/battery_session.dart';
import '../../core/models/battery_state.dart';
import '../../core/services/unified_logger_service.dart';
import 'battery_chart_widget.dart';

import '../../core/models/chart_type.dart';

class ManualAdjustmentPanel extends StatefulWidget {
  final BatterySession? session;

  const ManualAdjustmentPanel({super.key, this.session});

  @override
  State<ManualAdjustmentPanel> createState() => _ManualAdjustmentPanelState();
}

class _ManualAdjustmentPanelState extends State<ManualAdjustmentPanel> {
  late TextEditingController _capacityController;
  late TextEditingController _cycleController;

  @override
  void initState() {
    super.initState();
    _capacityController = TextEditingController(text: widget.session?.nominalCapacity.toString() ?? '0');
    _cycleController = TextEditingController(text: widget.session?.currentCycle.toString() ?? '1');
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _cycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manual Adjustments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _capacityController,
            enabled: widget.session != null,
            decoration: const InputDecoration(labelText: 'Nominal Capacity (mAh)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cycleController,
            enabled: widget.session != null,
            decoration: const InputDecoration(labelText: 'Current Cycle Number', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.session == null ? null : () {
                final cap = int.tryParse(_capacityController.text);
                final cyc = int.tryParse(_cycleController.text);
                unifiedLogger.log('Manually updated session metadata: Cap=$cap, Cyc=$cyc', source: LogSource.ui);
                context.read<SessionProvider>().updateSessionMetadata(
                  widget.session!,
                  nominalCapacity: cap,
                  currentCycle: cyc,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Metadata updated and logged')),
                );
              },
              child: const Text('Update & Log Action'),
            ),
          ),
          const Divider(),
          const Text('Stage Filter', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Consumer<SessionProvider>(
            builder: (context, provider, child) {
              return Wrap(
                spacing: 8,
                children: [BatteryState.charging, BatteryState.discharging, BatteryState.rest].map((stage) {
                  final isSelected = provider.selectedStages.contains(stage);
                  return FilterChip(
                    label: Text(stage.displayName, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (_) => provider.toggleStage(stage),
                    selectedColor: Colors.blue.shade100,
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Graph Selection', style: TextStyle(fontWeight: FontWeight.bold)),
          Consumer<SessionProvider>(
            builder: (context, provider, child) {
              return Column(
                children: ChartType.values.map((type) {
                  return CheckboxListTile(
                    title: Text(type.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                    value: provider.visibleGraphs.contains(type),
                    onChanged: (_) => provider.toggleGraph(type),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          const Text('Analysis Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Consumer<SessionProvider>(
            builder: (context, provider, child) {
              final allCycles = <int>{};
              if (widget.session != null) {
                allCycles.addAll(widget.session!.dataHistory.map((d) => d.cycleNumber));
              }
              for (var sourceData in provider.analysisDataSources.values) {
                allCycles.addAll(sourceData.map((d) => d.cycleNumber));
              }
              final sortedCycles = allCycles.toList()..sort();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Cycles to Compare:', style: TextStyle(fontSize: 12)),
                  Wrap(
                    spacing: 4,
                    children: sortedCycles.map((cycle) {
                      final isSelected = provider.selectedCycles.contains(cycle);
                      return FilterChip(
                        label: Text('Cycle $cycle'),
                        selected: isSelected,
                        onSelected: (_) {
                          unifiedLogger.log('Toggled cycle filter: $cycle', source: LogSource.ui);
                          provider.toggleCycle(cycle);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Data Series & Colors:', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  // Show a color legend for each active line (Source - Cycle)
                  ...provider.selectedSources.expand((sourceId) {
                    return sortedCycles.where((c) => provider.selectedCycles.contains(c)).map((cycle) {
                      // Check if this series actually has data
                      bool hasData = false;
                      if (sourceId == 'live' && widget.session != null) {
                        hasData = widget.session!.dataHistory.any((d) => d.cycleNumber == cycle);
                      } else if (provider.analysisDataSources.containsKey(sourceId)) {
                        hasData = provider.analysisDataSources[sourceId]!.any((d) => d.cycleNumber == cycle);
                      }

                      if (!hasData) return const SizedBox.shrink();

                      final key = '$sourceId - Cycle $cycle';
                      final color = BatteryChartWidget.getSourceColor(key);
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, color: color),
                            const SizedBox(width: 8),
                            Text(
                              '${sourceId == 'live' ? 'Live' : sourceId} - Cyc $cycle',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      );
                    });
                  }),
                  const SizedBox(height: 16),
                  const Text('Filter Sources:', style: TextStyle(fontSize: 12)),
                  if (widget.session != null)
                    CheckboxListTile(
                      title: const Text('Live Capture', style: TextStyle(fontSize: 13)),
                      value: provider.selectedSources.contains('live'),
                      onChanged: (_) {
                        unifiedLogger.log('Toggled live source filter', source: LogSource.ui);
                        provider.toggleSource('live');
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ...provider.analysisDataSources.keys.map((source) {
                    return CheckboxListTile(
                      title: Text(source, style: const TextStyle(fontSize: 13)),
                      value: provider.selectedSources.contains(source),
                      onChanged: (_) {
                        unifiedLogger.log('Toggled reference source filter: $source', source: LogSource.ui);
                        provider.toggleSource(source);
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
