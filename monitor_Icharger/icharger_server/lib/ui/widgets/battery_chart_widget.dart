import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/models/serial_data.dart';
import '../../core/services/unified_logger_service.dart';
import '../../core/utils/svg_export_helper.dart';

import '../../core/models/chart_type.dart';
import '../../providers/session_provider.dart';

class BatteryChartWidget extends StatefulWidget {
  final List<SerialData> data;
  final ChartType type;
  final String title;
  final Color color;
  final double? minX;
  final double? maxX;
  final Function(double, double)? onZoomChanged;

  const BatteryChartWidget({
    super.key,
    required this.data,
    required this.type,
    required this.title,
    this.color = Colors.blue,
    this.minX,
    this.maxX,
    this.onZoomChanged,
  });

  static Color getSourceColor(String key) {
    if (key.startsWith('live')) return Colors.blue;
    return Colors.primaries[key.hashCode % Colors.primaries.length];
  }

  @override
  State<BatteryChartWidget> createState() => _BatteryChartWidgetState();
}

class _BatteryChartWidgetState extends State<BatteryChartWidget> {
  double? _dragStartX;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final timeScale = provider.timeScale;
    final precision = widget.type == ChartType.voltage ? provider.voltagePrecision : 
                     (widget.type == ChartType.current ? provider.currentPrecision : 0);

    if (widget.data.isEmpty) {
      return Center(child: Text('No data for ${widget.title}'));
    }

    final Map<String, List<FlSpot>> series = {};
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var point in widget.data) {
      final key = '${point.sourceId} - Cycle ${point.cycleNumber}';
      series.putIfAbsent(key, () => []);
      
      double val;
      switch (widget.type) {
        case ChartType.voltage:
          val = point.voltageV;
          break;
        case ChartType.current:
          val = point.currentMA;
          break;
        case ChartType.capacity:
          val = point.capacityMAh.toDouble();
          break;
      }
      
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
      
      series[key]!.add(FlSpot(point.cycleTime * timeScale, val));
    }

    // Adjust Y range slightly for padding
    final yRange = maxY - minY;
    if (yRange == 0) {
      minY = minY - 1;
      maxY = maxY + 1;
    } else {
      minY = minY - (yRange * 0.1);
      maxY = maxY + (yRange * 0.1);
    }

    final List<LineChartBarData> lines = series.entries.map((entry) {
      return LineChartBarData(
        spots: entry.value,
        isCurved: false,
        color: BatteryChartWidget.getSourceColor(entry.key),
        barWidth: 2,
        dotData: const FlDotData(show: false),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.file_download, size: 18),
                tooltip: 'Export SVG',
                onPressed: () => _handleExport(context, lines, series.keys.toList(), minY, maxY),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 24.0, left: 8.0, bottom: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onHorizontalDragStart: (details) {
                    _dragStartX = details.localPosition.dx;
                  },
                  onHorizontalDragUpdate: (details) {
                    // Visual feedback could be added here
                  },
                  onHorizontalDragEnd: (details) {
                    final dragEndX = details.localPosition.dx;
                    if (_dragStartX == null) return;
                    if ((dragEndX - _dragStartX!).abs() < 10) return;

                    final fullWidth = constraints.maxWidth;
                    final dataMinX = widget.minX ?? lines.expand((l) => l.spots).map((s) => s.x).reduce((a, b) => a < b ? a : b);
                    final dataMaxX = widget.maxX ?? lines.expand((l) => l.spots).map((s) => s.x).reduce((a, b) => a > b ? a : b);
                    
                    final startRatio = (_dragStartX! / fullWidth).clamp(0.0, 1.0);
                    final endRatio = (dragEndX / fullWidth).clamp(0.0, 1.0);
                    
                    final newMin = dataMinX + (startRatio * (dataMaxX - dataMinX));
                    final newMax = dataMinX + (endRatio * (dataMaxX - dataMinX));
                    
                    widget.onZoomChanged?.call(
                      newMin < newMax ? newMin : newMax,
                      newMin < newMax ? newMax : newMin,
                    );
                  },
                  child: RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        minX: widget.minX,
                        maxX: widget.maxX,
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: lines,
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toStringAsFixed(precision), style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: Text('Time (${timeScale == 1.0 ? 's' : (timeScale == 1/60 ? 'm' : 'unit')})', style: const TextStyle(fontSize: 10)),
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '${spot.y.toStringAsFixed(precision)}\n${spot.x.toStringAsFixed(1)}',
                                  const TextStyle(color: Colors.white, fontSize: 10),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleExport(BuildContext context, List<LineChartBarData> lines, List<String> lineNames, double minY, double maxY) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'icharger_${widget.title.replaceAll(' ', '_').toLowerCase()}_$timestamp.svg';
      final filePath = p.join(appDir.path, fileName);
      
      final currentMinX = widget.minX ?? lines.expand((l) => l.spots).map((s) => s.x).reduce((a, b) => a < b ? a : b);
      final currentMaxX = widget.maxX ?? lines.expand((l) => l.spots).map((s) => s.x).reduce((a, b) => a > b ? a : b);

      await SvgExportHelper.exportLineChart(
        filePath: filePath,
        title: widget.title,
        lines: lines,
        lineNames: lineNames,
        minX: currentMinX,
        maxX: currentMaxX,
        minY: minY,
        maxY: maxY,
      );

      unifiedLogger.log('Exported chart to SVG: $fileName', source: LogSource.ui);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $fileName')),
      );
    } catch (e) {
      unifiedLogger.log('Error exporting SVG: $e', source: LogSource.crash);
    }
  }
}
