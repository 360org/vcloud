import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat/application/conversations_controller.dart';
import 'package:vcloud/features/chat/data/chat_repository.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart';
import 'package:vcloud/shared/models/profile.dart';

class _FakeChatV2Repository extends Fake implements ChatV2Repository {
  @override
  Future<List<ChatV2Member>> fetchChannelMembers(String channelId) async {
    return [
      const ChatV2Member(id: '1', name: 'Nguyễn Văn A', isMe: true),
      const ChatV2Member(id: '2', name: 'Trần Thị B', isMe: false),
      const ChatV2Member(id: '3', name: 'Lê Văn C', isMe: false),
    ];
  }

  @override
  Future<Map<String, dynamic>> addChannelMembers({
    required String channelId,
    required List<int> partnerIds,
  }) async {
    return {
      'status': 'success',
      'channel_id': int.tryParse(channelId) ?? 101,
      'member_count': 3 + partnerIds.length,
      'added_partner_ids': partnerIds,
    };
  }
}

class _FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<List<Profile>> allUsers() async {
    return const [
      Profile(id: '1', partnerId: '1', email: 'a@example.com', displayName: 'Nguyễn Văn A'),
      Profile(id: '2', partnerId: '2', email: 'b@example.com', displayName: 'Trần Thị B'),
      Profile(id: '4', partnerId: '4', email: 'd@example.com', displayName: 'Phạm Văn D'),
    ];
  }
}

void main() {
  group('Chat Group Add Member Tests (10 Independent Test Cases)', () {
    final fakeRepoV2 = _FakeChatV2Repository();
    final fakeRepoChat = _FakeChatRepository();

    const testGroupChannel = ChatV2Channel(
      id: '101',
      name: 'Nhóm Kỹ Thuật 360',
      channelType: 'group',
      isGroup: true,
      memberCount: 3,
      members: [
        ChatV2Member(id: '1', name: 'Nguyễn Văn A', isMe: true),
        ChatV2Member(id: '2', name: 'Trần Thị B', isMe: false),
        ChatV2Member(id: '3', name: 'Lê Văn C', isMe: false),
      ],
      memberNames: ['Nguyễn Văn A', 'Trần Thị B', 'Lê Văn C'],
    );

    const testDirectChannel = ChatV2Channel(
      id: '102',
      name: 'Trò chuyện 1-1',
      channelType: 'chat',
      isGroup: false,
      memberCount: 2,
      members: [
        ChatV2Member(id: '1', name: 'Nguyễn Văn A', isMe: true),
        ChatV2Member(id: '2', name: 'Trần Thị B', isMe: false),
      ],
      memberNames: ['Nguyễn Văn A', 'Trần Thị B'],
    );

    Widget buildTestWidget(Widget child) {
      return ProviderScope(
        overrides: [
          chatV2RepositoryProvider.overrideWithValue(fakeRepoV2),
          chatRepositoryProvider.overrideWithValue(fakeRepoChat),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: child,
        ),
      );
    }

    // TC-01: Kiểm tra kênh nhóm (group) hiển thị nút "Thêm thành viên" trên thanh tác vụ tròn
    testWidgets('TC-01: Kênh nhóm hiển thị nút Thêm thành viên trên thanh tác vụ tròn', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testGroupChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm thành viên'), findsOneWidget);
      expect(find.byIcon(LucideIcons.userPlus), findsWidgets);
    });

    // TC-02: Kiểm tra kênh nhóm hiển thị dòng "Thêm thành viên mới" trong danh sách thành viên
    testWidgets('TC-02: Kênh nhóm hiển thị dòng Thêm thành viên mới trong danh sách thành viên', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testGroupChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm thành viên mới'), findsOneWidget);
    });

    // TC-03: Kiểm tra kênh chat 1-1 không hiển thị nút "Thêm thành viên" trên thanh tác vụ tròn
    testWidgets('TC-03: Kênh chat 1-1 không hiển thị nút Thêm thành viên', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testDirectChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm thành viên'), findsNothing);
      expect(find.text('Thêm thành viên mới'), findsNothing);
    });

    // TC-04: Bấm nút "Thêm thành viên" mở BottomSheet modal
    testWidgets('TC-04: Bấm nút Thêm thành viên mở BottomSheet thêm thành viên', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testGroupChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addMemberBtn = find.text('Thêm thành viên');
      expect(addMemberBtn, findsOneWidget);
      await tester.tap(addMemberBtn);
      await tester.pumpAndSettle();

      // Modal BottomSheet xuất hiện với tiêu đề và thanh tìm kiếm
      expect(find.text('Tìm theo tên hoặc email...'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });

    // TC-05: Bấm nút "Thêm thành viên mới" trong danh sách cũng mở BottomSheet
    testWidgets('TC-05: Bấm nút Thêm thành viên mới trong danh sách mở BottomSheet', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testGroupChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addMemberRow = find.text('Thêm thành viên mới');
      expect(addMemberRow, findsOneWidget);
      await tester.tap(addMemberRow);
      await tester.pumpAndSettle();

      expect(find.text('Tìm theo tên hoặc email...'), findsOneWidget);
    });

    // TC-06: BottomSheet có nút đóng (Icon X) để đóng modal
    testWidgets('TC-06: Bấm icon X đóng BottomSheet thêm thành viên', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testGroupChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm thành viên'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      // Đã đóng BottomSheet
      expect(find.text('Tìm theo tên hoặc email...'), findsNothing);
    });

    // TC-07: Nút submit ở trạng thái disabled khi chưa chọn thành viên nào
    testWidgets('TC-07: Nút submit disabled khi chưa chọn thành viên nào', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testGroupChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm thành viên'));
      await tester.pumpAndSettle();

      final submitBtnFinder = find.widgetWithText(FilledButton, 'Thêm vào nhóm (0)');
      expect(submitBtnFinder, findsOneWidget);
      final submitBtn = tester.widget<FilledButton>(submitBtnFinder);
      expect(submitBtn.onPressed, isNull);
    });

    // TC-08: Model ChatV2Member hỗ trợ parse đúng trường avatarUrl và imStatus
    test('TC-08: ChatV2Member parse JSON đầy đủ thông tin', () {
      final json = {
        'id': 10,
        'name': 'Lê Hoàng Nam',
        'email': 'nam@example.com',
        'avatar_url': 'http://example.com/avatar.png',
        'im_status': 'online',
        'is_me': false,
      };
      final member = ChatV2Member.fromJson(json);
      expect(member.id, equals('10'));
      expect(member.name, equals('Lê Hoàng Nam'));
      expect(member.email, equals('nam@example.com'));
      expect(member.imStatus, equals('online'));
      expect(member.isMe, isFalse);
    });

    // TC-09: ChatV2Channel getActualIsGroup phân biệt chính xác group vs direct chat
    test('TC-09: ChatV2Channel getActualIsGroup nhận diện đúng group', () {
      expect(testGroupChannel.getActualIsGroup('Nguyễn Văn A'), isTrue);
      expect(testDirectChannel.getActualIsGroup('Nguyễn Văn A'), isFalse);
    });

    // TC-10: Hiển thị đúng số lượng thành viên ban đầu của nhóm
    testWidgets('TC-10: Hiển thị đúng số lượng thành viên ban đầu của nhóm', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ChatV2InfoSheet(
            channel: testGroupChannel,
            currentUserName: 'Nguyễn Văn A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề danh sách thành viên có hiển thị (3)
      expect(find.text('Danh sách thành viên (3)'), findsOneWidget);
    });
  });
}
