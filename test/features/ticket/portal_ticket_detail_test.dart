import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/ticket/data/ticket_comment_repository.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/features/ticket/presentation/ticket_detail_screen.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/ticket_activity.dart';
import 'package:vcloud/shared/models/ticket_comment.dart';

class _MockAuthController extends AuthController {
  _MockAuthController(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

class _MockTicketRepository extends TicketRepository {
  _MockTicketRepository(this._ticket);
  final Ticket _ticket;

  @override
  Future<Ticket> one(String id) async => _ticket;

  @override
  Future<List<TicketActivity>> activities(String ticketId, {bool includeDone = false}) async => const [];
}

class _MockTicketCommentRepository extends TicketCommentRepository {
  _MockTicketCommentRepository({this.comments = const []});
  final List<TicketComment> comments;

  @override
  Stream<List<TicketComment>> watchByTicket(String ticketId) => Stream.value(comments);
}

void main() {
  group('B.17: Portal Ticket Detail Role Isolation & Customer Experience Tests', () {
    const portalUser = AuthUser(
      id: '101',
      email: 'customer_portal@test.com',
      userMetadata: {
        'is_portal': true,
        'display_name': 'Khách Hàng Portal',
      },
    );

    const employeeUser = AuthUser(
      id: '2',
      email: 'mitchell_admin@test.com',
      userMetadata: {
        'is_portal': false,
        'display_name': 'Kỹ Thuật Viên Mitchell',
      },
    );

    final sampleTicket = Ticket(
      id: '99',
      title: 'Hệ thống báo lỗi kết nối máy in hóa đơn',
      description: 'Máy in không phản hồi khi ấn in từ màn hình POS.',
      status: TicketStatus.todo,
      createdBy: '101',
      assignedTo: '',
      createdAt: DateTime(2026, 10, 16, 8, 30),
      updatedAt: DateTime(2026, 10, 16, 8, 30),
      partnerName: 'Công ty Cổ phần Bán Lẻ ABC',
      assignedUserName: 'Nguyễn Tuấn Anh',
    );

    // -------------------------------------------------------------------------
    // Case 1: Portal Customer -> _TicketActionBar (Nhận / Hoàn thành) KHÔNG tồn tại
    // -------------------------------------------------------------------------
    testWidgets('Case 1: Portal Customer (_isPortal == true) hides Ticket Action Bar completely', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Không hiển thị nút "Nhận ticket" hay "Hoàn thành"
      expect(find.text('Nhận ticket'), findsNothing);
      expect(find.text('Hoàn thành'), findsNothing);
      expect(find.text('Nhận (Trễ SLA)'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Case 2: Portal Customer -> Khối Hoạt động _TicketActivitiesSection KHÔNG hiển thị
    // -------------------------------------------------------------------------
    testWidgets('Case 2: Portal Customer hides internal Activity Section (mail.activity)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Không hiển thị tiêu đề "Hoạt động" hoặc nút "+ Thêm"
      expect(find.text('Hoạt động'), findsNothing);
      expect(find.text('+ Thêm'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Case 3: Portal Customer -> Icon Chuyển giao và Bút sửa trên Header bị ẩn hoàn toàn
    // -------------------------------------------------------------------------
    testWidgets('Case 3: Portal Customer hides Header Edit and Reassign action icons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Không hiển thị icon bút chì sửa ticket
      expect(find.byIcon(LucideIcons.pencil), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Case 4: Portal Customer -> Khung nhập phản hồi _CommentComposer hiển thị sẵn sàng ở đáy
    // -------------------------------------------------------------------------
    testWidgets('Case 4: Portal Customer displays pinned Comment Composer at the bottom', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Khung nhập bình luận hiển thị
      expect(find.text('Nhập nội dung phản hồi...'), findsOneWidget);
      expect(find.byIcon(LucideIcons.send), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 5: Kỹ thuật viên nội bộ (!isPortal) -> Hiển thị đủ Action Bar và Hoạt động (Zero Regression)
    // -------------------------------------------------------------------------
    testWidgets('Case 5: Internal Engineer displays Action Bar, Edit icon, and Activity Section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(employeeUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Nhân viên nội bộ thấy nút "Nhận ticket" và "Hoàn thành"
      expect(find.text('Nhận ticket'), findsOneWidget);
      expect(find.text('Hoàn thành'), findsOneWidget);

      // Thấy icon Bút chì trên header
      expect(find.byIcon(LucideIcons.pencil), findsOneWidget);

      // Thấy khối Hoạt động
      expect(find.text('Hoạt động'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 6: Render mượt mà khi ticket có tệp đính kèm
    // -------------------------------------------------------------------------
    testWidgets('Case 6: Ticket renders attachments smoothly without errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ticketWithAttachments = Ticket(
        id: '100',
        title: 'Lỗi in hóa đơn kèm ảnh chụp màn hình',
        description: 'Đính kèm ảnh màn hình lỗi',
        status: TicketStatus.doing,
        createdBy: '101',
        assignedTo: '2',
        createdAt: DateTime(2026, 10, 16, 9, 0),
        updatedAt: DateTime(2026, 10, 16, 9, 15),
        attachments: const [
          MobileAttachment(
            id: 501,
            attachmentId: 501,
            name: 'printer_error_log.pdf',
            mimetype: 'application/pdf',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(ticketWithAttachments)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '100'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tệp đính kèm (1)'), findsOneWidget);
      expect(find.text('printer_error_log.pdf'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 7: B.18 - Mã số hiệu Ticket trên AppBar và nút sao chép 1-chạm
    // -------------------------------------------------------------------------
    testWidgets('Case 7: B.18 - AppBar displays formatted ticket number with copy button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tiêu đề AppBar hiển thị dạng: #99 · Ticket
      expect(find.text('#99 · Ticket'), findsOneWidget);
      // Nút copy mã vé tồn tại
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 8: B.18 - Ngày gửi yêu cầu trên Thẻ thông tin _TicketInfoCard
    // -------------------------------------------------------------------------
    testWidgets('Case 8: B.18 - Ticket Info Card displays creation date and time chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Chip Ngày gửi yêu cầu hiển thị chính xác
      expect(find.text('Ngày gửi: 16/10/2026 08:30'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 9: B.18 - Nút kẹp tệp đính kèm trên TicketCommentComposer
    // -------------------------------------------------------------------------
    testWidgets('Case 9: B.18 - Comment Composer includes paperclip attachment button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Nút đính kèm ảnh/tệp hiển thị trong composer
      expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 10: B.18 - Phân định Chuyên viên hỗ trợ trong Chatter
    // -------------------------------------------------------------------------
    testWidgets('Case 10: B.18 - Chatter displays Technician badge on support staff comment', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final techComment = TicketComment(
        id: '201',
        ticketId: '99',
        authorId: '2',
        authorName: 'Nguyễn Tuấn Anh',
        content: 'Chào bạn, kỹ thuật đã nhận thông tin và đang kiểm tra máy in.',
        createdAt: DateTime(2026, 10, 16, 9, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(sampleTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository(comments: [techComment])),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Badge Chuyên viên hỗ trợ hiển thị trên comment của nhân viên kỹ thuật
      expect(find.text('Chuyên viên hỗ trợ'), findsWidgets);
      expect(find.byIcon(LucideIcons.shieldCheck), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // Case 11: B.18 - Banner Hoàn thành & Nút Yêu cầu hỗ trợ thêm cho Portal
    // -------------------------------------------------------------------------
    testWidgets('Case 11: B.18 - Resolved Banner displays for Portal user when ticket is done', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final doneTicket = Ticket(
        id: '99',
        title: 'Hệ thống báo lỗi kết nối máy in hóa đơn',
        description: 'Máy in không phản hồi khi ấn in từ màn hình POS.',
        status: TicketStatus.done,
        createdBy: '101',
        assignedTo: '2',
        createdAt: DateTime(2026, 10, 16, 8, 30),
        updatedAt: DateTime(2026, 10, 16, 11, 0),
        partnerName: 'Công ty Cổ phần Bán Lẻ ABC',
        assignedUserName: 'Nguyễn Tuấn Anh',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(doneTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Banner hoàn thành cho Portal khách hàng hiển thị
      expect(find.text('Yêu cầu đã hoàn thành'), findsOneWidget);
      expect(find.text('Cần hỗ trợ thêm / Mở lại'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 12: B.18 - Zero Regression: Nhân viên nội bộ khi Ticket Done dùng _TicketActionBar
    // -------------------------------------------------------------------------
    testWidgets('Case 12: B.18 - Internal user sees Ticket Action Bar reopen button when done', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final doneTicket = Ticket(
        id: '99',
        title: 'Hệ thống báo lỗi kết nối máy in hóa đơn',
        description: 'Máy in không phản hồi khi ấn in từ màn hình POS.',
        status: TicketStatus.done,
        createdBy: '101',
        assignedTo: '2',
        createdAt: DateTime(2026, 10, 16, 8, 30),
        updatedAt: DateTime(2026, 10, 16, 11, 0),
        partnerName: 'Công ty Cổ phần Bán Lẻ ABC',
        assignedUserName: 'Nguyễn Tuấn Anh',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(employeeUser)),
            ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(doneTicket)),
            ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
          ],
          child: const MaterialApp(
            home: TicketDetailScreen(ticketId: '99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Không hiển thị banner của Portal
      expect(find.text('Yêu cầu đã hoàn thành'), findsNothing);
      // Hiển thị nút Mở lại ticket tiêu chuẩn của kỹ thuật viên
      expect(find.text('Mở lại ticket'), findsOneWidget);
    });
  });
}
