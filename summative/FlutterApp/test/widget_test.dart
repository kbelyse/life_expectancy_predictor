import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_expectancy_predictor/main.dart';

void main() {
  testWidgets('Prediction page has Status field and Predict button', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeExpectancyApp());
    await tester.pump();

    expect(find.text('Life Expectancy Predictor'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Status'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Predict'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(19));
  });
}
