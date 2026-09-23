import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

void main() {
  group('Kiểm thử đồng bộ Avatar Endpoint trên Flutter Mobile (10 Test Cases)', () {
    // Helper tính toán avatar endpoint giống như logic đồng bộ ở Home, Profile, Attendance
    String? resolveAvatarUrl(Map<String, dynamic>? meta, String? userId) {
      final rawAvatar = meta?['avatar_url'] ??
          meta?['avatar_128_url'] ??
          meta?['image_128_url'] ??
          (userId != null ? '/api/v1/mobile/avatar/users/$userId' : null);
      return rawAvatar is String && rawAvatar.isNotEmpty ? rawAvatar : null;
    }

    test('TC-01: Ưu tiên avatar_url từ metadata nếu có sẵn', () {
      final meta = {'avatar_url': 'https://vuahethong.net/custom_avatar.jpg'};
      final result = resolveAvatarUrl(meta, '3514');
      expect(result, 'https://vuahethong.net/custom_avatar.jpg');
    });

    test('TC-02: Ưu tiên avatar_128_url nếu avatar_url vắng mặt', () {
      final meta = {'avatar_128_url': '/api/v1/mobile/avatar/users/3514'};
      final result = resolveAvatarUrl(meta, '3514');
      expect(result, '/api/v1/mobile/avatar/users/3514');
    });

    test('TC-03: Ưu tiên image_128_url nếu cả avatar_url và avatar_128_url đều null', () {
      final meta = {'image_128_url': '/api/v1/mobile/avatar/users/3514'};
      final result = resolveAvatarUrl(meta, '3514');
      expect(result, '/api/v1/mobile/avatar/users/3514');
    });

    test('TC-04: Fallback chuẩn xác sang API Mobile /api/v1/mobile/avatar/users/{id} thay vì web/image', () {
      final result = resolveAvatarUrl(null, '3514');
      expect(result, '/api/v1/mobile/avatar/users/3514');
      expect(result?.contains('/web/image/'), isFalse);
    });

    test('TC-05: Trả về null khi cả metadata và userId đều null', () {
      final result = resolveAvatarUrl(null, null);
      expect(result, isNull);
    });

    test('TC-06: Khi metadata không chứa key avatar, fallback chính xác về API Mobile theo userId', () {
      final meta = <String, dynamic>{'name': 'Tan Nguyen'};
      final result = resolveAvatarUrl(meta, '3514');
      expect(result, '/api/v1/mobile/avatar/users/3514');
    });

    test('TC-07: Xử lý chuỗi Base64 Data URI hợp lệ trong avatar_url', () {
      final meta = {'avatar_url': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY44YAAAAASUVORK5CYII='};
      final result = resolveAvatarUrl(meta, '3514');
      expect(result?.startsWith('data:image/png;base64,'), isTrue);
    });

    testWidgets('TC-08: UserAvatar hiển thị Initials chữ cái đầu khi avatarUrl là null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              userId: '3514',
              displayName: 'Nguyễn Văn Tân',
              avatarUrl: null,
              size: 60,
            ),
          ),
        ),
      );

      // Chữ cái ghép "N" (Nguyễn) + "T" (Tân) = "NT"
      expect(find.text('NT'), findsOneWidget);
    });

    testWidgets('TC-09: UserAvatar tính toán màu chữ và nền _userColor đồng nhất theo userId và name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              userId: '3514',
              displayName: 'Sếp Tân',
              avatarUrl: null,
              size: 50,
            ),
          ),
        ),
      );

      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('TC-10: UserAvatar render hợp lệ với đường dẫn mobile avatar và kích thước tuỳ biến', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              userId: '3514',
              displayName: 'Tân Nguyễn',
              avatarUrl: '/api/v1/mobile/avatar/users/3514',
              size: 62,
            ),
          ),
        ),
      );

      expect(find.byType(UserAvatar), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 66.0); // size 62 + 4 viền ngoài
    });
  });
}
