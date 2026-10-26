import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/menu/application/menu_controller.dart';
import 'package:vcloud/features/menu/data/menu_item_model.dart';
import 'package:vcloud/features/menu/data/menu_repository.dart';

class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository({this.shouldThrow = false});

  final bool shouldThrow;

  @override
  Future<({List<AppMenuItem> apps, List<AppUtilityItem> utilities})>
      fetchAppsMenu() async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return (
      apps: const [
        AppMenuItem(
          id: 102,
          name: 'Chuyên cần',
          nativeRoute: '/timesheet',
          isNative: true,
          isBookmarked: true,
        ),
        AppMenuItem(
          id: 105,
          name: 'Kế toán',
          webUrl: '/web#action=210&menu_id=105',
          isNative: false,
          isBookmarked: false,
        ),
        AppMenuItem(
          id: 108,
          name: 'Tuyển dụng',
          webUrl: '/web#action=300&menu_id=108',
          isNative: false,
          isBookmarked: false,
        ),
      ],
      utilities: const [
        AppUtilityItem(
          id: 'support',
          name: 'Yêu cầu hỗ trợ',
          nativeRoute: '/tickets',
        ),
      ],
    );
  }
}

void main() {
  group('AppMenuItem & AppUtilityItem model', () {
    test('fromJson and toJson roundtrip correctly', () {
      final json = {
        'id': 102,
        'name': 'Chuyên cần',
        'xmlid': 'hr_attendance.menu_hr_attendance_root',
        'action_id': 145,
        'web_icon': 'hr_attendance,static/description/icon.png',
        'web_icon_data': 'data:image/png;base64,abc123==',
        'native_route': '/timesheet',
        'is_native': true,
        'is_bookmarked': true,
      };

      final item = AppMenuItem.fromJson(json);
      expect(item.id, 102);
      expect(item.name, 'Chuyên cần');
      expect(item.xmlid, 'hr_attendance.menu_hr_attendance_root');
      expect(item.actionId, 145);
      expect(item.webIcon, 'hr_attendance,static/description/icon.png');
      expect(item.webIconData, 'data:image/png;base64,abc123==');
      expect(item.nativeRoute, '/timesheet');
      expect(item.isNative, isTrue);
      expect(item.isBookmarked, isTrue);

      final exported = item.toJson();
      expect(exported['id'], 102);
      expect(exported['is_native'], isTrue);
      expect(exported['is_bookmarked'], isTrue);
    });

    test('copyWith works as expected', () {
      const item = AppMenuItem(id: 1, name: 'Test', isNative: false);
      final updated = item.copyWith(isNative: true, name: 'Updated');
      expect(updated.id, 1);
      expect(updated.name, 'Updated');
      expect(updated.isNative, isTrue);
    });

    test('AppUtilityItem parses fromJson correctly', () {
      final json = {
        'id': 'docs',
        'name': 'Tài liệu hướng dẫn',
        'icon': 'book_open',
        'url': '/help/docs',
      };
      final item = AppUtilityItem.fromJson(json);
      expect(item.id, 'docs');
      expect(item.name, 'Tài liệu hướng dẫn');
      expect(item.icon, 'book_open');
      expect(item.url, '/help/docs');
    });
  });

  group('MenuController', () {
    test('loads menu and filters by search query and tabs', () async {
      final fakeRepo = _FakeMenuRepository();
      final controller = MenuController(fakeRepo);

      await controller.loadMenu();
      expect(controller.state.apps.length, 3);
      expect(controller.state.utilities.length, 1);
      expect(controller.state.bookmarkedIds.contains(102), isTrue);

      // Search query filter
      controller.setSearchQuery('kế toán');
      expect(controller.state.filteredApps.length, 1);
      expect(controller.state.filteredApps.first.id, 105);

      // Reset query
      controller.setSearchQuery('');
      expect(controller.state.filteredApps.length, 3);

      // Bookmark tab filter
      controller.setActiveTab('bookmark');
      expect(controller.state.filteredApps.length, 1);
      expect(controller.state.filteredApps.first.id, 102);

      // Toggle bookmark for Kế toán (105)
      controller.toggleBookmark(105);
      expect(controller.state.filteredApps.length, 2);

      // Untoggle bookmark for Kế toán
      controller.toggleBookmark(105);
      expect(controller.state.filteredApps.length, 1);
    });

    test('falls back to default utilities if repository returns empty',
        () async {
      final fakeRepo = _FakeMenuRepository(shouldThrow: true);
      final controller = MenuController(fakeRepo);

      await controller.loadMenu();
      expect(controller.state.apps, isEmpty);
      expect(controller.state.utilities.length, 3); // default utilities
    });
  });
}
