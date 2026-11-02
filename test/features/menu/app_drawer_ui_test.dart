import 'package:flutter/material.dart' hide MenuController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/menu/application/menu_controller.dart';
import 'package:vcloud/features/menu/data/menu_item_model.dart';
import 'package:vcloud/features/menu/data/menu_repository.dart';
import 'package:vcloud/features/menu/presentation/app_drawer_bottom_sheet.dart';

class _FakeMenuRepo extends MenuRepository {
  _FakeMenuRepo({this.apps = const []});

  final List<AppMenuItem> apps;

  @override
  Future<({List<AppMenuItem> apps, List<AppUtilityItem> utilities})>
      fetchAppsMenu() async {
    return (
      apps: apps,
      utilities: const [
        AppUtilityItem(
          id: 'docs',
          name: 'Tài liệu hướng dẫn',
          icon: 'book_open',
          url: '/help',
        ),
      ],
    );
  }
}

void main() {
  const sampleApps = [
    AppMenuItem(
      id: 1,
      name: 'Chuyên cần',
      nativeRoute: '/timesheet',
      isNative: true,
      isBookmarked: false,
    ),
    AppMenuItem(
      id: 2,
      name: 'Kế toán',
      webUrl: '/web#action=200',
      isNative: false,
      isBookmarked: false,
    ),
    AppMenuItem(
      id: 3,
      name: 'Tuyển dụng',
      webUrl: '/web#action=300',
      isNative: false,
      isBookmarked: false,
    ),
  ];

  Widget buildTestWidget({
    Size screenSize = const Size(390, 844),
    List<AppMenuItem> apps = sampleApps,
    String initialTab = 'all',
  }) {
    final fakeRepo = _FakeMenuRepo(apps: apps);
    return ProviderScope(
      overrides: [
        menuControllerProvider.overrideWith((ref) {
          final c = MenuController(fakeRepo);
          c.setActiveTab(initialTab);
          return c;
        }),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: const Scaffold(
            body: AppDrawerBottomSheet(),
          ),
        ),
      ),
    );
  }

  group('AppDrawer UI/UX & Responsive Suite (12 Cases)', () {
    testWidgets('Case 1: Search bar is completely removed from App Drawer',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Tìm kiếm ứng dụng...'), findsNothing);
    });

    testWidgets('Case 2: Header displays Tab "Đã ghim" with bookmark icon',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Đã ghim'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bookmark), findsAtLeastNWidgets(1));
    });

    testWidgets('Case 3: Header displays Tab "Tất cả" with grid icon and badge count',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.byIcon(LucideIcons.layoutGrid), findsAtLeastNWidgets(1));
      expect(find.text('3'), findsOneWidget); // 3 apps
    });

    testWidgets('Case 4: Header displays Close button (✕) with tooltip',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      expect(find.byTooltip('Đóng'), findsOneWidget);
    });

    testWidgets('Case 5: Tapping Close button pops Navigator', (tester) async {
      var didPop = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ProviderScope(
                      overrides: [
                        menuControllerProvider.overrideWith(
                            (ref) => MenuController(_FakeMenuRepo())),
                      ],
                      child: const AppDrawerBottomSheet(),
                    ),
                  ).then((_) => didPop = true);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDrawerBottomSheet), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
    });

    testWidgets('Case 6: Empty state for bookmark tab displays title',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialTab: 'bookmark'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có ứng dụng được ghim'), findsOneWidget);
    });

    testWidgets('Case 7: Empty state for bookmark displays guidance text',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialTab: 'bookmark'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nhấn giữ bất kỳ ứng dụng nào ở mục Tất cả để ghim lối tắt vào đây.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Case 8: Empty state for bookmark displays bookmarkPlus icon',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialTab: 'bookmark'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.bookmarkPlus), findsOneWidget);
    });

    testWidgets('Case 9: App cards are wrapped in RepaintBoundary for 120Hz scrolling',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final cardFinder = find.text('Chuyên cần');
      expect(cardFinder, findsOneWidget);

      final repaintBoundaryAncestors = find.ancestor(
        of: cardFinder,
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundaryAncestors, findsAtLeastNWidgets(1));
    });

    testWidgets('Case 10: App cards include AnimatedScale for micro-interaction',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final animatedScaleFinders = find.byType(AnimatedScale);
      expect(animatedScaleFinders, findsAtLeastNWidgets(3));
    });

    testWidgets('Case 11: Mobile small screen (<360px) sets 4 columns grid',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();

      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate = sliverGrid.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(4));
    });

    testWidgets('Case 12: Tablet screen (>=600px) sets 6 columns and maxWidth 620',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        screenSize: const Size(768, 1024),
      ));
      await tester.pumpAndSettle();

      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate = sliverGrid.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(6));

      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 620,
      );
      expect(constrainedBoxFinder, findsOneWidget);
    });
  });
}
