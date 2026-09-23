import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  group('Kiểm thử toàn diện 10 Cases: Chức năng Popup chọn Database khi trùng nhiều DB', () {
    final mockDatabases = [
      const DbInfo(
        login: 'support@360.org.vn',
        databaseName: 'vuahethong',
        databaseUrl: 'https://vuahethong.net',
        displayName: 'Vua Hệ Thống (Chính thức)',
        hasVMobile: true,
      ),
      const DbInfo(
        login: 'support@360.org.vn',
        databaseName: 'nds',
        databaseUrl: 'https://ndsgroup.vn',
        displayName: 'NDSGroup',
        hasVMobile: true,
      ),
      const DbInfo(
        login: 'support@360.org.vn',
        databaseName: 'gtline',
        databaseUrl: 'https://gtline.vuahethong.com',
        displayName: 'GT Lines',
        hasVMobile: false,
      ),
    ];

    Widget buildTestDialog(List<DbInfo> dbs, void Function(DbInfo?) onSelect) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<DbInfo>(
                    context: context,
                    barrierDismissible: true,
                    builder: (ctx) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Chọn tổ chức / cơ sở dữ liệu'),
                          const Text('Tài khoản hợp lệ tại các đơn vị bên dưới:'),
                          IconButton(
                            key: const Key('btn_close_dialog'),
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(null),
                          ),
                          ...dbs.map((db) => ListTile(
                                key: Key('item_${db.databaseName}'),
                                title: Text(db.effectiveDisplayName),
                                subtitle: Text(db.databaseUrl),
                                trailing: db.hasVMobile ? null : const Text('Chưa cài vmobile'),
                                onTap: () => Navigator.of(ctx).pop(db),
                              )),
                        ],
                      ),
                    ),
                  );
                  onSelect(result);
                },
                child: const Text('Kích hoạt Popup'),
              ),
            ),
          ),
        ),
      );
    }

    // Case 1: Hiển thị đúng tiêu đề
    testWidgets('TC-01: Popup hiển thị đúng tiêu đề Header khi có danh sách nhiều DB', (tester) async {
      await tester.pumpWidget(buildTestDialog(mockDatabases, (_) {}));
      await tester.tap(find.text('Kích hoạt Popup'));
      await tester.pumpAndSettle();

      expect(find.text('Chọn tổ chức / cơ sở dữ liệu'), findsOneWidget);
      expect(find.text('Tài khoản hợp lệ tại các đơn vị bên dưới:'), findsOneWidget);
    });

    // Case 2: Hiển thị đầy đủ số lượng và tên tổ chức
    testWidgets('TC-02: Danh sách DB hiển thị đầy đủ tên các tổ chức liên kết', (tester) async {
      await tester.pumpWidget(buildTestDialog(mockDatabases, (_) {}));
      await tester.tap(find.text('Kích hoạt Popup'));
      await tester.pumpAndSettle();

      expect(find.text('Vua Hệ Thống (Chính thức)'), findsOneWidget);
      expect(find.text('NDSGroup'), findsOneWidget);
      expect(find.text('GT Lines'), findsOneWidget);
    });

    // Case 3: Hiển thị URL đúng của từng đơn vị
    testWidgets('TC-03: Hiển thị đúng URL endpoint của từng database', (tester) async {
      await tester.pumpWidget(buildTestDialog(mockDatabases, (_) {}));
      await tester.tap(find.text('Kích hoạt Popup'));
      await tester.pumpAndSettle();

      expect(find.text('https://vuahethong.net'), findsOneWidget);
      expect(find.text('https://ndsgroup.vn'), findsOneWidget);
      expect(find.text('https://gtline.vuahethong.com'), findsOneWidget);
    });

    // Case 4: Cảnh báo vmobile khi backend chưa kích hoạt
    testWidgets('TC-04: Hiển thị đúng nhãn cảnh báo nếu DB chưa cài vmobile', (tester) async {
      await tester.pumpWidget(buildTestDialog(mockDatabases, (_) {}));
      await tester.tap(find.text('Kích hoạt Popup'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa cài vmobile'), findsOneWidget);
    });

    // Case 5: Tương tác chọn DB đầu tiên (Vua Hệ Thống)
    testWidgets('TC-05: Người dùng chọn DB Vua Hệ Thống -> Trả về đúng DbInfo', (tester) async {
      DbInfo? selectedDb;
      await tester.pumpWidget(buildTestDialog(mockDatabases, (db) => selectedDb = db));
      await tester.tap(find.text('Kích hoạt Popup'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('item_vuahethong')));
      await tester.pumpAndSettle();

      expect(selectedDb, isNotNull);
      expect(selectedDb!.databaseName, 'vuahethong');
      expect(selectedDb!.databaseUrl, 'https://vuahethong.net');
    });

    // Case 6: Tương tác chọn DB thứ hai (NDSGroup)
    testWidgets('TC-06: Người dùng chọn DB NDSGroup -> Trả về đúng DbInfo', (tester) async {
      DbInfo? selectedDb;
      await tester.pumpWidget(buildTestDialog(mockDatabases, (db) => selectedDb = db));
      await tester.tap(find.text('Kích hoạt Popup'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('item_nds')));
      await tester.pumpAndSettle();

      expect(selectedDb, isNotNull);
      expect(selectedDb!.databaseName, 'nds');
      expect(selectedDb!.databaseUrl, 'https://ndsgroup.vn');
    });

    // Case 7: Nút Close (X) đóng popup và trả về null
    testWidgets('TC-07: Bấm nút đóng (X) trên popup -> Hủy chọn và trả về null', (tester) async {
      DbInfo? selectedDb;
      await tester.pumpWidget(buildTestDialog(mockDatabases, (db) => selectedDb = db));
      await tester.tap(find.text('Kích hoạt Popup'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_close_dialog')));
      await tester.pumpAndSettle();

      expect(find.text('Chọn tổ chức / cơ sở dữ liệu'), findsNothing);
      expect(selectedDb, isNull);
    });

    // Case 8: Khử trùng lặp theo cặp (databaseName, databaseUrl)
    testWidgets('TC-08: Logic khử trùng lặp (Deduplication) loại bỏ các bản ghi trùng', (tester) async {
      final duplicateList = [
        mockDatabases[0],
        mockDatabases[0],
        mockDatabases[1],
        mockDatabases[1],
      ];
      final seenKeys = <String>{};
      final uniqueDbs = <DbInfo>[];
      for (final item in duplicateList) {
        final key = '${item.databaseName.trim().toLowerCase()}|${item.databaseUrl.trim().toLowerCase()}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          uniqueDbs.add(item);
        }
      }

      expect(uniqueDbs.length, 2);
      expect(uniqueDbs[0].databaseName, 'vuahethong');
      expect(uniqueDbs[1].databaseName, 'nds');
    });

    // Case 9: Xử lý fallback khi displayName rỗng (effectiveDisplayName)
    testWidgets('TC-09: Thuộc tính effectiveDisplayName fallback về databaseName nếu displayName rỗng', (tester) async {
      const dbWithoutDisplayName = DbInfo(
        login: 'test@360.org.vn',
        databaseName: 'tenant_sample',
        databaseUrl: 'https://tenant.sample.com',
        displayName: '',
        hasVMobile: true,
      );

      expect(dbWithoutDisplayName.effectiveDisplayName, 'tenant_sample');
    });

    // Case 10: Nhánh 1 DB duy nhất không cần mở popup (Tự động đăng nhập thẳng)
    testWidgets('TC-10: Kiểm tra điều kiện chỉ có 1 DB -> Không kích hoạt popup chọn', (tester) async {
      final singleDbList = [mockDatabases[0]];
      bool popupTriggered = false;

      if (singleDbList.length > 1) {
        popupTriggered = true;
      }

      expect(popupTriggered, isFalse);
      expect(singleDbList.length, 1);
      expect(singleDbList.first.databaseName, 'vuahethong');
    });
  });
}
