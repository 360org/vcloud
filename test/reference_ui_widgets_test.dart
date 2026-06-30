import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/ticket/presentation/create_ticket_screen.dart';
import 'package:vcloud/shared/widgets/ui_kit.dart';

void main() {
  test('UnreadBadge formats planned count thresholds', () {
    expect(UnreadBadge.format(1), '1');
    expect(UnreadBadge.format(9), '9');
    expect(UnreadBadge.format(10), '10+');
    expect(UnreadBadge.format(42), '10+');
    expect(UnreadBadge.format(100), '99+');
  });

  testWidgets('SegmentedTabs changes selected option', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SegmentedTabs(
                labels: const ['Direct', 'Groups'],
                selectedIndex: selected,
                onChanged: (index) => setState(() => selected = index),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('CreateTicketScreen defaults to P3 and validates title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateTicketScreen())),
    );

    expect(find.textContaining('P3'), findsOneWidget);

    await tester.tap(find.text('Gửi ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Bắt buộc'), findsOneWidget);
  });
}
