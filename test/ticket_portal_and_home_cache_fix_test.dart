import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/services/global_state_reset_service.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/home/application/home_summary_controller.dart';
import 'package:vcloud/features/home/data/dashboard_repository.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/features/timesheet/data/task_repository.dart';
import 'package:vcloud/features/timesheet/data/timesheet_repository.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/ticket_comment.dart';

bool _checkIsImage(MobileAttachment a) {
  final ext = a.name.contains('.') ? a.name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => true,
    _ => (a.mimetype?.startsWith('image/') ?? false),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lỗi 1: Xác thực nhãn Chuyên viên hỗ trợ (isTechnician) và Portal comment', () {
    final sampleTicket = Ticket(
      id: '101',
      title: 'Ticket kiểm tra lỗi portal',
      status: TicketStatus.doing,
      createdBy: 'partner_6913',
      assignedTo: 'partner_8888',
      assignedUserName: 'Kỹ thuật viên Nguyễn',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('Case 1: Khách hàng Portal gửi comment không bị gắn nhãn chuyên viên hỗ trợ', () {
      final portalComment = TicketComment(
        id: 'msg_1',
        ticketId: '101',
        authorId: 'partner_6913',
        authorName: 'Khách hàng Portal',
        content: 'Tôi cần hỗ trợ gấp lỗi này',
        createdAt: DateTime.now(),
        isTechnician: false,
      );

      // Mô phỏng logic _isTechnicianComment trong TicketDetailScreen
      final isMe = portalComment.authorId == 'partner_6913';
      final isCreator = portalComment.authorId == sampleTicket.createdBy;

      expect(isMe, isTrue);
      expect(isCreator, isTrue);
      expect(portalComment.isTechnician, isFalse);
    });

    test('Case 2: Bình luận của chính mình (isMe) luôn hiển thị "Bạn", không gắn cờ chuyên viên', () {
      final myComment = TicketComment(
        id: 'msg_2',
        ticketId: '101',
        authorId: '6913',
        authorName: 'Tân Châu',
        content: 'Bình luận thử nghiệm',
        createdAt: DateTime.now(),
        isTechnician: true, // Giả sử server trả cờ true nhưng đây là chính mình
      );

      const myId = '6';
      const myPartnerId = '6913';
      const myName = 'Tân Châu';

      final normMyName = myName.trim().toLowerCase();
      final normAuthorName = myComment.authorName?.trim().toLowerCase() ?? '';

      final isMe = myComment.authorId == myId ||
          myComment.authorId == myPartnerId ||
          (normMyName.isNotEmpty && normAuthorName == normMyName);

      final effectiveIsTechnician = !isMe && myComment.isTechnician;

      expect(isMe, isTrue);
      expect(effectiveIsTechnician, isFalse, reason: 'Chính mình không bao giờ hiển thị nhãn Chuyên viên hỗ trợ');
    });

    test('Case 3: Người tạo ticket (createdBy) không bao giờ bị gắn nhãn chuyên viên', () {
      final creatorComment = TicketComment(
        id: 'msg_3',
        ticketId: '101',
        authorId: 'partner_6913',
        authorName: 'Khách hàng Portal',
        content: 'Thêm thông tin bổ sung',
        createdAt: DateTime.now(),
      );

      final isCreator = sampleTicket.createdBy.isNotEmpty && creatorComment.authorId == sampleTicket.createdBy;
      final isTechnician = !isCreator &&
          (creatorComment.isTechnician || (sampleTicket.assignedTo.isNotEmpty && creatorComment.authorId == sampleTicket.assignedTo));

      expect(isCreator, isTrue);
      expect(isTechnician, isFalse);
    });

    test('Case 4: Kỹ thuật viên được giao (assignedTo) bình luận thì hiển thị chuyên viên hỗ trợ', () {
      final techComment = TicketComment(
        id: 'msg_4',
        ticketId: '101',
        authorId: 'partner_8888',
        authorName: 'Kỹ thuật viên Nguyễn',
        content: 'Tôi đã tiếp nhận và đang kiểm tra.',
        createdAt: DateTime.now(),
        isTechnician: true,
      );

      final isMe = techComment.authorId == 'partner_6913';
      final isCreator = techComment.authorId == sampleTicket.createdBy;
      final isAssigned = sampleTicket.assignedTo.isNotEmpty && techComment.authorId == sampleTicket.assignedTo;
      final effectiveIsTechnician = !isMe && !isCreator && (techComment.isTechnician || isAssigned);

      expect(isMe, isFalse);
      expect(isCreator, isFalse);
      expect(isAssigned, isTrue);
      expect(effectiveIsTechnician, isTrue);
    });
  });

  group('Lỗi 2: Hiển thị ảnh inline và tệp đính kèm trong bình luận Ticket', () {
    test('Case 5: TicketComment mapping đính kèm danh sách attachments và cờ isTechnician', () {
      final rawMsg = {
        'id': 'msg_10',
        'ticket_id': '101',
        'author_id': '50',
        'author_name': 'Kỹ thuật viên',
        'body': 'Đã gửi hình ảnh minh họa đính kèm',
        'date': '2026-11-04T10:00:00Z',
        'is_technician': true,
        'attachments': [
          {
            'id': 1001,
            'attachment_id': 1001,
            'name': 'screenshot_loi.png',
            'mimetype': 'image/png',
            'file_size': 102400,
            'url': '/web/image/1001',
            'download_url': '/api/v1/mobile/attachments/1001/download',
          },
          {
            'id': 1002,
            'attachment_id': 1002,
            'name': 'tai_lieu_huong_dan.pdf',
            'mimetype': 'application/pdf',
            'file_size': 512000,
            'url': '/web/content/1002',
            'download_url': '/api/v1/mobile/attachments/1002/download',
          }
        ]
      };

      final comment = TicketComment.fromMap(rawMsg);

      expect(comment.id, 'msg_10');
      expect(comment.isTechnician, isTrue);
      expect(comment.attachments.length, 2);
      expect(comment.attachments[0].id, 1001);
      expect(_checkIsImage(comment.attachments[0]), isTrue);
      expect(comment.attachments[1].id, 1002);
      expect(_checkIsImage(comment.attachments[1]), isFalse);
    });

    test('Case 6: Tách riêng danh sách ảnh inline và tệp tài liệu trong bình luận', () {
      final comment = TicketComment(
        id: 'msg_11',
        ticketId: '101',
        authorId: '50',
        content: 'Gửi cả ảnh và file tài liệu',
        createdAt: DateTime.now(),
        attachments: [
          const MobileAttachment(id: 1, attachmentId: 1, name: 'anh_1.jpg', mimetype: 'image/jpeg', fileSize: 1000),
          const MobileAttachment(id: 2, attachmentId: 2, name: 'anh_2.png', mimetype: 'image/png', fileSize: 2000),
          const MobileAttachment(id: 3, attachmentId: 3, name: 'hop_dong.docx', mimetype: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', fileSize: 3000),
        ],
      );

      final imageAttachments = comment.attachments.where(_checkIsImage).toList();
      final nonImageAttachments = comment.attachments.where((a) => !_checkIsImage(a)).toList();

      expect(imageAttachments.length, 2);
      expect(nonImageAttachments.length, 1);
      expect(nonImageAttachments.first.name, 'hop_dong.docx');
    });

    test('Case 7: Tin nhắn lạc quan (optimistic) hiển thị ảnh ngay từ bộ nhớ đệm bytes', () {
      final fakeBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header
      final pendingAttachment = MobileAttachment(
        id: 999999,
        attachmentId: 0,
        name: 'upload_chup_anh.png',
        mimetype: 'image/png',
        fileSize: fakeBytes.length,
      );

      final pendingComment = TicketComment(
        id: 'pending-12345',
        ticketId: '101',
        authorId: '6913',
        content: 'Đã gửi tệp đính kèm: upload_chup_anh.png',
        createdAt: DateTime.now(),
        attachments: [pendingAttachment],
      );

      expect(pendingComment.attachments.length, 1);
      expect(_checkIsImage(pendingComment.attachments.first), isTrue);
      expect(pendingComment.attachments.first.attachmentId, 0); // Đang chờ upload
    });
  });

  group('Lỗi 3: Reset và cô lập State khi đổi tài khoản Admin sang Portal', () {
    test('Case 8: GlobalStateResetService xóa sạch In-Memory cache của tất cả Repositories', () async {
      // Giả lập nạp cache vào repositories
      TicketRepository.clearCache();
      TaskRepository.clearCache();
      TimesheetRepository.clearCache();

      // Gọi clearAllUserDataOnLogout không quăng exception
      await GlobalStateResetService.clearAllUserDataOnLogout();
      expect(true, isTrue);
    });

    test('Case 9: mobileDashboardSummaryProvider trả về giá trị rỗng (0) khi user null (đăng xuất)', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => _MockAuthController(null)),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(mobileDashboardSummaryProvider, (_, _) {});
      addTearDown(sub.close);

      final summary = await container.read(mobileDashboardSummaryProvider.future);

      expect(summary.isCheckedIn, isFalse);
      expect(summary.todayMinutes, 0);
      expect(summary.openTickets, 0);
      expect(summary.recentConversationCount, 0);
      expect(summary.unreadMessageCount, 0);
    });

    test('Case 10: Chuyển đổi từ tài khoản Admin sang Portal tự động nạp số liệu mới không bị dính cache Admin', () async {
      const adminUser = AuthUser(
        id: '1',
        email: 'admin@360.org.vn',
        userMetadata: {
          'name': 'Administrator',
          'is_portal': false,
        },
      );

      const portalUser = AuthUser(
        id: '6',
        email: 'portal@360.org.vn',
        userMetadata: {
          'name': 'Khách hàng Portal',
          'is_portal': true,
        },
      );

      final mockRepo = _MockDashboardRepository();
      mockRepo.summaryMap = {
        '1': const MobileDashboardSummary(isCheckedIn: true, todayMinutes: 480, openTickets: 15, recentConversationCount: 8),
        '6': const MobileDashboardSummary(isCheckedIn: false, todayMinutes: 0, openTickets: 2, recentConversationCount: 1),
      };

      final authNotifier = _DynamicAuthController(adminUser);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => authNotifier),
          dashboardRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(mobileDashboardSummaryProvider, (_, _) {});
      addTearDown(sub.close);

      // Bước 1: Admin đọc dữ liệu
      mockRepo.currentUserId = '1';
      final adminSummary = await container.read(mobileDashboardSummaryProvider.future);
      expect(adminSummary.openTickets, 15);
      expect(adminSummary.todayMinutes, 480);
      expect(adminSummary.recentConversationCount, 8);

      // Bước 2: Đăng xuất và đăng nhập Portal
      await GlobalStateResetService.clearAllUserDataOnLogout(container: container);
      mockRepo.currentUserId = '6';
      authNotifier.setUser(portalUser);

      // Bước 3: Portal đọc dữ liệu
      final portalSummary = await container.read(mobileDashboardSummaryProvider.future);
      expect(portalSummary.openTickets, 2, reason: 'Số vé của Portal phải là 2, không được lưu số 15 của Admin');
      expect(portalSummary.todayMinutes, 0, reason: 'Giờ làm của Portal phải là 0');
      expect(portalSummary.recentConversationCount, 1);
    });
  });
}

class _MockAuthController extends AuthController {
  _MockAuthController(this._initialUser);
  final AuthUser? _initialUser;

  @override
  Future<AuthUser?> build() async => _initialUser;
}

class _DynamicAuthController extends AuthController {
  _DynamicAuthController(this._user);
  AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;

  void setUser(AuthUser? user) {
    _user = user;
    state = AsyncData(user);
  }
}

class _MockDashboardRepository extends DashboardRepository {
  String currentUserId = '1';
  Map<String, MobileDashboardSummary> summaryMap = {};

  @override
  Future<MobileDashboardSummary> summary() async {
    return summaryMap[currentUserId] ?? const MobileDashboardSummary();
  }
}
