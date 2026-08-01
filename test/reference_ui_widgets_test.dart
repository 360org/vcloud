import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/notifications/push_notification_controller.dart';
import 'package:vcloud/core/notifications/push_notification_repository.dart';
import 'package:vcloud/features/attendance/application/attendance_controller.dart';
import 'package:vcloud/features/chat/application/conversations_controller.dart';
import 'package:vcloud/features/home/presentation/home_screen.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/ticket/data/ticket_comment_repository.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/features/ticket/presentation/create_ticket_screen.dart';
import 'package:vcloud/features/ticket/presentation/ticket_detail_screen.dart';
import 'package:vcloud/features/timesheet/application/task_controller.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/features/timesheet/data/task_repository.dart';
import 'package:vcloud/features/timesheet/presentation/timesheet_list_screen.dart';
import 'package:vcloud/features/timesheet/presentation/widgets/checklist_editor.dart';
import 'package:vcloud/shared/models/conversation.dart';
import 'package:vcloud/shared/models/attendance.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/ticket_comment.dart';
import 'package:vcloud/shared/models/timesheet.dart';
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

  testWidgets('CompactActionTile fits tight dashboard grid cells', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 89.3,
              height: 93.1,
              child: CompactActionTile(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                color: Colors.blue,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('CreateTicketScreen defaults to P3 and validates title', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ticketTeamsProvider.overrideWith(
            (ref) async => const <TicketTeamOption>[
              TicketTeamOption(id: 1, name: 'Hỗ trợ chung'),
            ],
          ),
        ],
        child: const MaterialApp(home: CreateTicketScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bình thường'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Gửi ticket'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Gửi ticket'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập tiêu đề'), findsOneWidget);
  });

  testWidgets(
    'Timer save sheet shows only projects with open tasks and expands tasks',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = TaskRepository(client: _FakeTimerProjectClient());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(repo),
            todayTasksProvider.overrideWith(
              (ref) => Stream<List<Task>>.value(const <Task>[]),
            ),
            timesheetStreamProvider.overrideWith(
              (ref) =>
                  Stream<List<TimesheetEntry>>.value(const <TimesheetEntry>[]),
            ),
            totalUnreadCountProvider.overrideWithValue(0),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/timesheet',
              routes: [
                GoRoute(
                  path: '/timesheet',
                  builder: (_, _) => const TimesheetListScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.play));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.save));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Open Project'), findsOneWidget);
      expect(find.text('Empty Project'), findsNothing);
      expect(find.text('Done Project'), findsNothing);
      expect(find.text('Open timer task'), findsNothing);

      await tester.ensureVisible(find.text('Open Project'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Open Project'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Open timer task'), findsOneWidget);
    },
  );

  testWidgets("Tapping a row in 'Công việc hôm nay' opens a quick-edit popup "
      'with note + duration + save actions', (tester) async {
    final client = _FakeHomeTaskClient();
    final repo = TaskRepository(client: client);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceTodayProvider.overrideWith(
            (ref) => Stream<Attendance?>.value(null),
          ),
          taskRepositoryProvider.overrideWithValue(repo),
          todayTasksProvider.overrideWith(
            (ref) => Stream<List<Task>>.value(<Task>[
              _task(
                id: '99',
                title: 'Today task A',
                projectId: '1',
                projectName: 'Project A',
              ),
            ]),
          ),
          conversationsProvider.overrideWith(
            (ref) => Stream<List<ConversationSummary>>.value(
              const <ConversationSummary>[],
            ),
          ),
          ticketsProvider.overrideWith(
            (ref) => Stream<List<Ticket>>.value(const <Ticket>[]),
          ),
          totalUnreadCountProvider.overrideWithValue(0),
          // Bell now reads the real notification API as a polling stream;
          // pin it to an empty list so the home tree stays idle in tests
          // (otherwise the timer keeps emitting and pumpAndSettle never settles).
          mobileNotificationsProvider.overrideWith(
            (ref) => Stream<MobileNotificationList>.value(
              const MobileNotificationList(
                items: <MobileNotificationItem>[],
                total: 0,
                limit: 50,
                offset: 0,
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Today task A'),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    // Row renders the task title verbatim from the fake API.
    expect(find.text('Today task A'), findsOneWidget);

    // Tap → bottom sheet opens.
    await tester.tap(find.text('Today task A'));
    await tester.pumpAndSettle();

    // Sheet contains the shared editor + the save button with the
    // "Lưu cập nhật" label that the home flow chose.
    expect(find.byType(TaskChecklistEditor), findsOneWidget);
    expect(find.text('Lưu cập nhật'), findsOneWidget);
    expect(
      find.text('Cập nhật nội dung & thời gian làm việc.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Home bell opens notification sheet with unread chat and tickets',
    (tester) async {
      final now = DateTime(2026, 7, 6, 9);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceTodayProvider.overrideWith(
              (ref) => Stream<Attendance?>.value(null),
            ),
            todayTasksProvider.overrideWith(
              (ref) => Stream<List<Task>>.value(const <Task>[]),
            ),
            conversationsProvider.overrideWith(
              (ref) =>
                  Stream<List<ConversationSummary>>.value(<ConversationSummary>[
                    ConversationSummary(
                      id: '42',
                      isGroup: true,
                      title: 'Team VCloud',
                      lastMessage: null,
                      updatedAt: now,
                      unreadCount: 2,
                    ),
                  ]),
            ),
            ticketsProvider.overrideWith(
              (ref) => Stream<List<Ticket>>.value(<Ticket>[
                Ticket(
                  id: '7',
                  title: 'Máy in lỗi',
                  status: TicketStatus.doing,
                  createdBy: '3',
                  assignedTo: '3',
                  createdAt: now,
                  updatedAt: now,
                ),
              ]),
            ),
            totalUnreadCountProvider.overrideWithValue(2),
            // Bell now renders the real notification API feed. Pin it to a
            // fixed list so the sheet has deterministic content and the
            // polling timer doesn't keep pumpAndSettle alive.
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream<MobileNotificationList>.value(
                const MobileNotificationList(
                  items: <MobileNotificationItem>[
                    MobileNotificationItem(
                      id: 1,
                      eventType: 'message',
                      title: 'Team VCloud',
                      body: 'Bạn có 2 tin nhắn mới',
                      data: <String, dynamic>{'channel_id': 42},
                      status: 'sent',
                    ),
                    MobileNotificationItem(
                      id: 2,
                      eventType: 'ticket_assigned',
                      title: 'Máy in lỗi',
                      body: 'Bạn được gán một ticket',
                      data: <String, dynamic>{'ticket_id': 7},
                      status: 'sent',
                    ),
                  ],
                  total: 2,
                  limit: 50,
                  offset: 0,
                  hasMore: false,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pumpAndSettle();

      // The unified notification feed shows the bell header and each
      // notification's title (no more inferred chat/ticket sections).
      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Team VCloud'), findsOneWidget);
      expect(find.text('Máy in lỗi'), findsOneWidget);
    },
  );

  testWidgets('TicketDetailScreen shows newest comments first', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ticketRepositoryProvider.overrideWithValue(_FakeTicketRepository()),
          ticketCommentRepositoryProvider.overrideWithValue(
            _FakeTicketCommentRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const TicketDetailScreen(ticketId: '42'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Newest comment'), findsOneWidget);

    expect(find.text('Oldest comment'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newest comment')).dy,
      lessThan(tester.getTopLeft(find.text('Oldest comment')).dy),
    );
  });
}

class _FakeTicketRepository extends TicketRepository {
  _FakeTicketRepository() : super(client: _NeverCalledOdooClient());

  @override
  Future<Ticket> one(String id) async {
    final now = DateTime(2026, 7, 6, 9);
    return Ticket(
      id: id,
      title: 'Ticket order test',
      status: TicketStatus.doing,
      createdBy: '3',
      assignedTo: '3',
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _FakeTicketCommentRepository extends TicketCommentRepository {
  _FakeTicketCommentRepository() : super(client: _NeverCalledOdooClient());

  @override
  Stream<List<TicketComment>> watchByTicket(String ticketId) {
    return Stream<List<TicketComment>>.value(<TicketComment>[
      TicketComment(
        id: 'old',
        ticketId: ticketId,
        authorId: '4',
        content: 'Oldest comment',
        createdAt: DateTime(2026, 7, 6, 8),
        authorName: 'Old User',
      ),
      TicketComment(
        id: 'new',
        ticketId: ticketId,
        authorId: '5',
        content: 'Newest comment',
        createdAt: DateTime(2026, 7, 6, 10),
        authorName: 'New User',
      ),
    ]);
  }
}

class _NeverCalledOdooClient extends OdooApiClient {
  _NeverCalledOdooClient() : super(baseUrl: 'https://example.test');
}

Task _task({
  required String id,
  required String title,
  String? projectId,
  String? projectName,
  bool completed = false,
}) {
  final now = DateTime(2026, 7, 4, 9);
  return Task(
    id: id,
    userId: '3',
    title: title,
    projectId: projectId,
    projectName: projectName,
    category: TimesheetCategory.other,
    dueDate: now,
    completedAt: completed ? now : null,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeHomeTaskClient extends OdooApiClient {
  _FakeHomeTaskClient() : super(baseUrl: 'https://example.test');

  int logCalls = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    if (path == '/api/v1/mobile/timesheet/projects') {
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Project A'},
      ];
    }
    if (path == '/api/v1/mobile/timesheet/projects/1/tasks') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 99,
          'name': 'Today task A',
          'project_id': 1,
          'user_id': 3,
          'state': '01_in_progress',
        },
      ];
    }
    if (path == '/api/v1/project.task/99') {
      return <String, dynamic>{
        'id': 99,
        'name': 'Today task A',
        'project_id': 1,
        'user_id': 3,
        'state': '01_in_progress',
      };
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    if (path == '/api/v1/mobile/timesheet/log') {
      logCalls++;
      return <String, dynamic>{
        'id': 1,
        'display_name': 'logged',
        'unit_amount': 0.5,
        'date': '2026-07-03',
      };
    }
    return <String, dynamic>{};
  }
}

class _FakeTimerProjectClient extends OdooApiClient {
  _FakeTimerProjectClient() : super(baseUrl: 'https://example.test');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    if (path == '/api/v1/mobile/project/list' ||
        path == '/api/v1/mobile/timesheet/projects') {
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Open Project'},
        <String, dynamic>{'id': 2, 'name': 'Empty Project'},
        <String, dynamic>{'id': 3, 'name': 'Done Project'},
      ];
    }
    if (path == '/api/v1/mobile/project/1/tasks' ||
        path == '/api/v1/mobile/timesheet/projects/1/tasks') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 11,
          'name': 'Open timer task',
          'project_id': 1,
          'user_id': 3,
          'state': '01_in_progress',
        },
      ];
    }
    if (path == '/api/v1/mobile/project/2/tasks' ||
        path == '/api/v1/mobile/timesheet/projects/2/tasks') {
      return <Map<String, dynamic>>[];
    }
    if (path == '/api/v1/mobile/project/3/tasks' ||
        path == '/api/v1/mobile/timesheet/projects/3/tasks') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 33,
          'name': 'Completed timer task',
          'project_id': 3,
          'user_id': 3,
          'state': '1_done',
        },
      ];
    }

    if (path == '/api/v1/project.task/11') {
      return <String, dynamic>{
        'id': 11,
        'name': 'Open timer task',
        'project_id': 1,
        'user_id': 3,
        'state': '01_in_progress',
      };
    }
    if (path == '/api/v1/project.task/33') {
      return <String, dynamic>{
        'id': 33,
        'name': 'Completed timer task',
        'project_id': 3,
        'user_id': 3,
        'state': '1_done',
      };
    }
    throw StateError('Unexpected GET $path');
  }
}
