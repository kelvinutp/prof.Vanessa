import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:battery_monitor_app/main.dart';

void main() {
  testWidgets('App launches without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const IChargerApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
