import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

void main() {
  group('Chat V2 Main Tab Switcher Overflow Protection Tests', () {
    Widget buildTestTabButton({
      required String label,
      required int count,
      double availableWidth = 155.0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: availableWidth,
              height: 42,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.inbox, size: 15),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        child: Text(count.toString()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('TC1: Tab button does not overflow at standard width (159px)', (tester) async {
      await tester.pumpWidget(buildTestTabButton(
        label: 'Hộp thư hệ thống',
        count: 0,
        availableWidth: 159.0,
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Hộp thư hệ thống'), findsOneWidget);
    });

    testWidgets('TC2: Tab button with badge count does not overflow at standard width (159px)', (tester) async {
      await tester.pumpWidget(buildTestTabButton(
        label: 'Hộp thư hệ thống',
        count: 16,
        availableWidth: 159.0,
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC3: Tab button handles extremely narrow width (100px) with ellipsis without overflow', (tester) async {
      await tester.pumpWidget(buildTestTabButton(
        label: 'Hộp thư hệ thống',
        count: 99,
        availableWidth: 100.0,
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC4: Dual tab row on small screen (320px) does not throw RenderFlex overflow exception', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: buildTestTabButton(label: 'Hội thoại', count: 16, availableWidth: 140),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: buildTestTabButton(label: 'Hộp thư hệ thống', count: 0, availableWidth: 140),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
