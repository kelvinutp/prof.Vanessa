import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/models/serial_data.dart';

class GraphingPanel extends StatefulWidget {
  final List<SerialData> data;
  const GraphingPanel({super.key, required this.data});

  @override
  State<GraphingPanel> createState() => _GraphingPanelState();
}

enum GraphType { voltage, current, capacity }

class _GraphingPanelState extends State<GraphingPanel> {
  GraphType _selectedType = GraphType.voltage;
  bool _isAutoScaling = true;
  double _minY = 0;
  double _maxY = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              DropdownButton<GraphType>(
                value: _selectedType,
                items: GraphType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Axis Config'),
                onPressed: _showAxisConfig,
              ),
            ],
          ),
        ),

        // Chart Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
            child: LineChart(
              LineChartData(
                minY: _isAutoScaling ? null : _minY,
                maxY: _isAutoScaling ? null : _maxY,
                lineBarsData: [_getLineData()],
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAxisConfig() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Axis Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Auto Scaling'),
                value: _isAutoScaling,
                onChanged: (val) {
                  setDialogState(() => _isAutoScaling = val);
                  setState(() => _isAutoScaling = val);
                },
              ),
              if (!_isAutoScaling) ...[
                TextField(
                  decoration: const InputDecoration(labelText: 'Min Y'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(() => _minY = double.tryParse(val) ?? 0),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Max Y'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(() => _maxY = double.tryParse(val) ?? 5),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  LineChartBarData _getLineData() {
    List<FlSpot> spots = [];
    for (int i = 0; i < widget.data.length; i++) {
      double yVal = 0;
      switch (_selectedType) {
        case GraphType.voltage:
          yVal = widget.data[i].voltageV;
          break;
        case GraphType.current:
          yVal = widget.data[i].currentMA;
          break;
        case GraphType.capacity:
          yVal = widget.data[i].capacityMAh.toDouble();
          break;
      }
      spots.add(FlSpot(i.toDouble(), yVal));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      barWidth: 2,
      color: Colors.blue,
      dotData: const FlDotData(show: false),
    );
  }
}
