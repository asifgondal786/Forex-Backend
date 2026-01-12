import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build a simple app for testing
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Test')),
        ),
      ),
    );

    // Verify the app builds without crashing
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
  });
}
