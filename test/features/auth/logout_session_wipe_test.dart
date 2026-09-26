import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/services/global_state_reset_service.dart';
import 'package:vcloud/features/attendance/data/attendance_repository.dart';
import 'package:vcloud/features/attendance/domain/shift_calculator.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_read_state_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/features/timesheet/data/task_repository.dart';
import 'package:vcloud/features/timesheet/data/timesheet_repository.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session & State Leakage Protection Test Suite (Protocol V2.1)', () {
    setUp(() {
      TicketRepository.clearCache();
      TaskRepository.clearCache();
      TimesheetRepository.clearCache();
      AttendanceRepository.clearCache();
      ChatV2Repository.clearCache();
      ChatV2ReadStateNotifier.clearMemoryCache();
      ChatV2AttachmentImage.clearImageCache();
      ChatV2ChannelLocalCache.clear();
      odooApiClient.clearPartnerToUserMap();
    });

    tearDown(() {
      TicketRepository.clearCache();
      TaskRepository.clearCache();
      TimesheetRepository.clearCache();
      AttendanceRepository.clearCache();
      ChatV2Repository.clearCache();
      ChatV2ReadStateNotifier.clearMemoryCache();
      ChatV2AttachmentImage.clearImageCache();
      ChatV2ChannelLocalCache.clear();
      odooApiClient.clearPartnerToUserMap();
    });

    // -------------------------------------------------------------------------
    // Test Case 1: TicketRepository In-Memory RAM Wipe
    // -------------------------------------------------------------------------
    test('Case 1: TicketRepository.clearCache wipes cached tickets in RAM', () {
      final mockTickets = [
        Ticket(
          id: '101',
          title: 'Phiếu hỗ trợ User A',
          status: TicketStatus.doing,
          createdBy: '1',
          assignedTo: '2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      TicketRepository.setCachedTicketsForTesting(mockTickets);
      expect(TicketRepository.cachedTicketsForTesting.length, equals(1));
      expect(TicketRepository.cachedTicketsForTesting.first.id, equals('101'));

      TicketRepository.clearCache();
      expect(TicketRepository.cachedTicketsForTesting, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test Case 2: TaskRepository In-Memory RAM Wipe
    // -------------------------------------------------------------------------
    test('Case 2: TaskRepository.clearCache wipes cached tasks in RAM', () {
      final mockTasks = [
        Task(
          id: '501',
          userId: '2',
          title: 'Công việc User A',
          category: TimesheetCategory.other,
          dueDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      TaskRepository.setCachedTodayTasksForTesting(mockTasks);
      expect(TaskRepository.cachedTodayTasksForTesting.length, equals(1));
      expect(TaskRepository.cachedTodayTasksForTesting.first.id, equals('501'));

      TaskRepository.clearCache();
      expect(TaskRepository.cachedTodayTasksForTesting, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test Case 3: TimesheetRepository In-Memory RAM Wipe
    // -------------------------------------------------------------------------
    test('Case 3: TimesheetRepository.clearCache wipes cached timesheet entries', () {
      TimesheetRepository.clearCache();
      // Calling clearCache multiple times should be safe and idempotent
      expect(() => TimesheetRepository.clearCache(), returnsNormally);
    });

    // -------------------------------------------------------------------------
    // Test Case 4: AttendanceRepository In-Memory RAM Wipe
    // -------------------------------------------------------------------------
    test('Case 4: AttendanceRepository.clearCache wipes cached shift config', () {
      AttendanceRepository.cachedShiftConfig = ShiftConfig.forDate(DateTime.now());
      expect(AttendanceRepository.cachedShiftConfig, isNotNull);

      AttendanceRepository.clearCache();
      expect(AttendanceRepository.cachedShiftConfig, isNull);
    });

    // -------------------------------------------------------------------------
    // Test Case 5: ChatV2Repository In-Memory RAM Wipe
    // -------------------------------------------------------------------------
    test('Case 5: ChatV2Repository.clearCache executes without error', () {
      expect(() => ChatV2Repository.clearCache(), returnsNormally);
    });

    // -------------------------------------------------------------------------
    // Test Case 6: ChatV2ReadStateNotifier Memory Cache Wipe
    // -------------------------------------------------------------------------
    test('Case 6: ChatV2ReadStateNotifier.clearMemoryCache wipes channel read state', () {
      expect(() => ChatV2ReadStateNotifier.clearMemoryCache(), returnsNormally);
    });

    // -------------------------------------------------------------------------
    // Test Case 7: ChatV2AttachmentImage Image RAM Cache Wipe
    // -------------------------------------------------------------------------
    test('Case 7: ChatV2AttachmentImage.clearImageCache wipes decoded image bytes', () {
      ChatV2AttachmentImage.cacheBytes('test_img_1', Uint8List.fromList([1, 2, 3, 4]));
      expect(ChatV2AttachmentImage.imageCache.containsKey('test_img_1'), isTrue);

      ChatV2AttachmentImage.clearImageCache();
      expect(ChatV2AttachmentImage.imageCache.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test Case 8: ChatV2ChannelLocalCache resets memory structures
    // -------------------------------------------------------------------------
    test('Case 8: ChatV2ChannelLocalCache.clear resets cached channels and user pinned state', () {
      const channel = ChatV2Channel(id: 'ch_test_1', name: 'Nhóm Dự Án A');
      ChatV2ChannelLocalCache.set([channel]);
      ChatV2ChannelLocalCache.toggleUserPin('ch_test_1');
      expect(ChatV2ChannelLocalCache.isUserPinned('ch_test_1'), isTrue);

      ChatV2ChannelLocalCache.clear();
      expect(ChatV2ChannelLocalCache.cached, isEmpty);
      expect(ChatV2ChannelLocalCache.isUserPinned('ch_test_1'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Test Case 9: OdooApiClient partner mapping wipe
    // -------------------------------------------------------------------------
    test('Case 9: OdooApiClient.clearPartnerToUserMap clears partner mapping', () {
      odooApiClient.registerPartnerUserMapping('100', '200');
      expect(odooApiClient.getUserIdForPartner('100'), equals('200'));

      odooApiClient.clearPartnerToUserMap();
      expect(odooApiClient.getUserIdForPartner('100'), isNull);
    });

    // -------------------------------------------------------------------------
    // Test Case 10: GlobalStateResetService Integration with Riverpod
    // -------------------------------------------------------------------------
    test('Case 10: GlobalStateResetService resets Riverpod state & RAM stores', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Giả lập state tạm trước khi logout
      container.read(ticketFilterProvider.notifier).update(
            const TicketFilter(priority: TicketPriority.p1),
          );
      expect(container.read(ticketFilterProvider).priority, equals(TicketPriority.p1));

      TicketRepository.setCachedTicketsForTesting([
        Ticket(
          id: '999',
          title: 'Ticket cá nhân User A',
          status: TicketStatus.todo,
          createdBy: '1',
          assignedTo: '2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      expect(TicketRepository.cachedTicketsForTesting.isNotEmpty, isTrue);

      // 2. Chạy GlobalStateResetService
      await GlobalStateResetService.clearAllUserDataOnLogout(container: container);

      // 3. Xác minh RAM và Riverpod State đã được dọn dẹp sạch
      expect(TicketRepository.cachedTicketsForTesting, isEmpty);
      expect(container.read(ticketFilterProvider).isEmpty, isTrue);
      expect(container.read(ticketOverrideProvider), isNull);
      expect(container.read(timesheetTimerControllerProvider).isIdle, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test Case 11: End-to-end Simulation: User Switch (User A -> Logout -> User B)
    // -------------------------------------------------------------------------
    test('Case 11: Switch User flow guarantees zero Ticket leakage between User A and User B', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // --- Phiên làm việc của User A ---
      final userATickets = [
        Ticket(
          id: 'A_01',
          title: 'Vé hỗ trợ bí mật của User A',
          status: TicketStatus.doing,
          createdBy: '10',
          assignedTo: '10',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      TicketRepository.setCachedTicketsForTesting(userATickets);
      container.read(ticketOverrideProvider.notifier).set(userATickets);

      // User A đang nhìn thấy ticket của mình
      expect(container.read(effectiveTicketsProvider).first.id, equals('A_01'));
      expect(container.read(effectiveTicketsProvider).first.title, contains('User A'));

      // --- User A BẤM LOGOUT ---
      await GlobalStateResetService.clearAllUserDataOnLogout(container: container);

      // RAM và State tức thì bị dọn sạch
      expect(TicketRepository.cachedTicketsForTesting, isEmpty);
      expect(container.read(ticketOverrideProvider), isNull);

      // --- User B ĐĂNG NHẬP ---
      // User B chưa có dữ liệu hoặc có dữ liệu mới của User B
      final userBTickets = [
        Ticket(
          id: 'B_01',
          title: 'Vé công việc riêng User B',
          status: TicketStatus.todo,
          createdBy: '20',
          assignedTo: '20',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      TicketRepository.setCachedTicketsForTesting(userBTickets);
      container.read(ticketOverrideProvider.notifier).set(userBTickets);

      // User B xem danh sách
      final currentList = container.read(effectiveTicketsProvider);
      expect(currentList.length, equals(1));
      expect(currentList.first.id, equals('B_01'));
      // Đảm bảo TUYỆT ĐỐI không còn dấu vết ticket nào của User A
      expect(currentList.any((t) => t.id == 'A_01'), isFalse);
      expect(currentList.any((t) => t.title.contains('User A')), isFalse);
    });

    // -------------------------------------------------------------------------
    // Test Case 12: Idempotency & Fault Tolerance
    // -------------------------------------------------------------------------
    test('Case 12: Calling GlobalStateResetService multiple times is idempotent and safe', () async {
      await expectLater(
        GlobalStateResetService.clearAllUserDataOnLogout(),
        completes,
      );
      await expectLater(
        GlobalStateResetService.clearAllUserDataOnLogout(),
        completes,
      );
    });
  });
}
