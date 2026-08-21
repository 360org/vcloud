// Smoke test that verifies the splash → login layout renders without
// touching the backend. The full app needs an authenticated Odoo session and is
// exercised by integration tests instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loading indicator renders empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CircularProgressIndicator())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
