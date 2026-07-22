import 'dart:io';
import 'package:fl_chart/fl_chart.dart';

class SvgExportHelper {
  static Future<void> exportLineChart({
    required String filePath,
    required String title,
    required List<LineChartBarData> lines,
    required List<String> lineNames,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) async {
    final width = 800.0;
    final legendHeight = 40.0;
    final height = 400.0 + legendHeight;
    final padding = 50.0;

    final chartWidth = width - (padding * 2);
    final chartHeight = (height - legendHeight) - (padding * 2);

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');
    
    // Background
    buffer.writeln('  <rect width="100%" height="100%" fill="white" />');
    
    // Title
    buffer.writeln('  <text x="${width / 2}" y="25" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold">$title</text>');

    // Chart Area Calculations
    final xRange = maxX - minX;
    final yRange = maxY - minY;

    // Grid and Labels
    final xTicks = 10;
    final yTicks = 5;

    // Y-axis grid and labels
    for (var i = 0; i <= yTicks; i++) {
      final yVal = minY + (i / yTicks * yRange);
      final yPos = (height - padding) - (i / yTicks * chartHeight);
      
      // Grid line
      buffer.writeln('  <line x1="$padding" y1="$yPos" x2="${width - padding}" y2="$yPos" stroke="#EEEEEE" stroke-width="1" />');
      // Label
      buffer.writeln('  <text x="${padding - 5}" y="${yPos + 4}" text-anchor="end" font-family="Arial" font-size="10">${yVal.toStringAsFixed(2)}</text>');
    }

    // X-axis grid and labels
    for (var i = 0; i <= xTicks; i++) {
      final xVal = minX + (i / xTicks * xRange);
      final xPos = padding + (i / xTicks * chartWidth);
      
      // Grid line
      buffer.writeln('  <line x1="$xPos" y1="$padding" x2="$xPos" y2="${height - padding}" stroke="#EEEEEE" stroke-width="1" />');
      // Label
      buffer.writeln('  <text x="$xPos" y="${height - padding + 15}" text-anchor="middle" font-family="Arial" font-size="10">${xVal.toStringAsFixed(0)}</text>');
    }

    // Main Axes
    buffer.writeln('  <line x1="$padding" y1="${height - padding}" x2="${width - padding}" y2="${height - padding}" stroke="black" stroke-width="1" />');
    buffer.writeln('  <line x1="$padding" y1="$padding" x2="$padding" y2="${height - padding}" stroke="black" stroke-width="1" />');

    // Axis Title
    buffer.writeln('  <text x="${width / 2}" y="${height - 5}" text-anchor="middle" font-family="Arial" font-size="12">Time (s)</text>');

    // Data Lines
    for (var line in lines) {
      if (line.spots.isEmpty) continue;
      
      final colorHex = '#${line.color!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      buffer.write('  <polyline fill="none" stroke="$colorHex" stroke-width="2" points="');
      
      for (var spot in line.spots) {
        if (spot.x < minX || spot.x > maxX) continue;
        
        final x = padding + ((spot.x - minX) / xRange * chartWidth);
        final y = (height - padding) - ((spot.y - minY) / yRange * chartHeight);
        
        buffer.write('${x.toStringAsFixed(2)},${y.toStringAsFixed(2)} ');
      }
      
      buffer.writeln('" />');
    }

    // Legend at the bottom
    var legendX = padding;
    var legendY = height - 20;
    
    for (int i = 0; i < lines.length; i++) {
      if (i >= lineNames.length) break;
      final colorHex = '#${lines[i].color!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      
      buffer.writeln('  <rect x="$legendX" y="${legendY - 8}" width="10" height="10" fill="$colorHex" />');
      buffer.writeln('  <text x="${legendX + 15}" y="$legendY" font-family="Arial" font-size="10">${lineNames[i]}</text>');
      
      legendX += (lineNames[i].length * 6) + 40;
      if (legendX > width - padding) {
        legendX = padding;
        legendY += 15;
      }
    }
    
    buffer.writeln('</svg>');

    final file = File(filePath);
    await file.writeAsString(buffer.toString());
  }
}
