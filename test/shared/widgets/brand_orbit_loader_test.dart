import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/widgets/brand_orbit_loader.dart';

void main() {
  group('BrandOrbitLoader Widget Tests', () {
    testWidgets('renders BrandOrbitLoader with default dimensions and custom painter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandOrbitLoader(size: 78),
            ),
          ),
        ),
      );

      // Verify widget exists
      expect(find.byType(BrandOrbitLoader), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Advance frames to ensure smooth animation ticks
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders BrandOrbitLoader with custom sizes and colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandOrbitLoader(
                size: 100,
                globeColor: Color(0xFF00CE2C),
                orbitColor: Color(0xFF0077CD),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BrandOrbitLoader), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('disposes controller cleanly without throwing exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandOrbitLoader(size: 60),
          ),
        ),
      );

      // Replace with empty container to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(BrandOrbitLoader), findsNothing);
    });
  });
}
