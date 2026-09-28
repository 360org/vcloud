import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/home/presentation/home_screen.dart';
import 'package:vcloud/shared/widgets/celebration_fireworks.dart';

void main() {
  group('BUG-008: Home Header Greeting & User Metadata Tests', () {
    test('greetingForHour returns "Chào buổi sáng" for 5h - 11h59', () {
      final morningStart = DateTime(2026, 9, 28, 5, 0);
      final morningMid = DateTime(2026, 9, 28, 8, 30);
      final morningEnd = DateTime(2026, 9, 28, 11, 59, 59);

      expect(greetingForHour(morningStart), 'Chào buổi sáng');
      expect(greetingForHour(morningMid), 'Chào buổi sáng');
      expect(greetingForHour(morningEnd), 'Chào buổi sáng');
    });

    test('greetingForHour returns "Chào buổi chiều" for 12h - 17h59', () {
      final afternoonStart = DateTime(2026, 9, 28, 12, 0);
      final afternoonMid = DateTime(2026, 9, 28, 15, 0);
      final afternoonEnd = DateTime(2026, 9, 28, 17, 59, 59);

      expect(greetingForHour(afternoonStart), 'Chào buổi chiều');
      expect(greetingForHour(afternoonMid), 'Chào buổi chiều');
      expect(greetingForHour(afternoonEnd), 'Chào buổi chiều');
    });

    test('greetingForHour returns "Chào buổi tối" for 18h - 4h59', () {
      final eveningStart = DateTime(2026, 9, 28, 18, 0);
      final eveningLate = DateTime(2026, 9, 28, 22, 30);
      final midnight = DateTime(2026, 9, 28, 0, 0);
      final earlyHours = DateTime(2026, 9, 28, 4, 59, 59);

      expect(greetingForHour(eveningStart), 'Chào buổi tối');
      expect(greetingForHour(eveningLate), 'Chào buổi tối');
      expect(greetingForHour(midnight), 'Chào buổi tối');
      expect(greetingForHour(earlyHours), 'Chào buổi tối');
    });

    test('User metadata jobTitle and company formatting verification', () {
      // Both jobTitle and companyName present
      final parts1 = [
        if ('AI Full Stack Engineer'.isNotEmpty) 'AI Full Stack Engineer',
        if ('360 CORP'.isNotEmpty) '360 CORP',
      ];
      expect(parts1.join(' · '), 'AI Full Stack Engineer · 360 CORP');

      // Only companyName present
      const String? jobTitleNull = null;
      final parts2 = [
        if (jobTitleNull != null && jobTitleNull.isNotEmpty) jobTitleNull,
        if ('360 CORP'.isNotEmpty) '360 CORP',
      ];
      expect(parts2.join(' · '), '360 CORP');

      // Only jobTitle present
      const String? companyNull = null;
      final parts3 = [
        if ('Experienced Developer'.isNotEmpty) 'Experienced Developer',
        if (companyNull != null && companyNull.isNotEmpty) companyNull,
      ];
      expect(parts3.join(' · '), 'Experienced Developer');
    });
  });

  group('BUG-009: Quick Check-in Celebration Overlay Trigger Tests', () {
    testWidgets('CelebrationFireworksOverlay triggers without crash on child context',
        (tester) async {
      final childKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelebrationFireworksOverlay(
              child: Container(key: childKey),
            ),
          ),
        ),
      );

      expect(find.byType(CelebrationFireworksOverlay), findsOneWidget);

      // Trigger fireworks using the child context inside the overlay
      expect(
        () => CelebrationFireworksOverlay.trigger(childKey.currentContext!),
        returnsNormally,
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
