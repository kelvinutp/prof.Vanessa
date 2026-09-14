// test/widget_test.dart (Updated to reference LabControlApp)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LabControlApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}