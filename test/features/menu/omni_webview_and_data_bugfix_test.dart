import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_inbox_item.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_inbox_tab.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import 'package:vcloud/features/menu/presentation/odoo_webview_screen.dart';
import 'package:vcloud/features/profile/presentation/profile_screen.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/features/timesheet/data/timesheet_repository.dart';
import 'package:vcloud/shared/models/ticket.dart';

class _StubOdooClient implements OdooApiClient {
  final List<String> calls = <String>[];
  final List<dynamic> bodies = <dynamic>[];
  dynamic getResult;
  dynamic postResult;
  dynamic deleteResult;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    calls.add('GET $path${query.isNotEmpty ? ' $query' : ''}');
    return getResult;
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    calls.add('POST $path');
    bodies.add(body);
    return postResult;
  }

  @override
  Future<dynamic> delete(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    calls.add('DELETE $path');
    return deleteResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final AuthUser _user;

  @override
  Future<AuthUser?> build() async => _user;
}

class _StubInboxController extends ChatV2InboxController {
  _StubInboxController(this._initialState);
  final ChatV2InboxState _initialState;

  @override
  ChatV2InboxState build() => _initialState;

  @override
  Future<void> loadActiveTab({bool refresh = false}) async {}
}

void main() {
  group('BUG-04: WebView Navigation Guard & Back Loop Prevention', () {
    test('evaluateWebViewNavigationDecision allows web schemes, launches tel/mailto/sms externally, blocks unknown schemes', () {
      expect(evaluateWebViewNavigationDecision('https://vuahethong.net/odoo/sale.order/1500'), WebViewNavigationAction.navigate);
      expect(evaluateWebViewNavigationDecision('http://192.168.1.100:1900/web'), WebViewNavigationAction.navigate);
      expect(evaluateWebViewNavigationDecision('about:blank'), WebViewNavigationAction.navigate);
      expect(evaluateWebViewNavigationDecision('data:text/html,hello'), WebViewNavigationAction.navigate);
      expect(evaluateWebViewNavigationDecision('blob:https://vuahethong.net/123'), WebViewNavigationAction.navigate);
      expect(evaluateWebViewNavigationDecision('javascript:void(0)'), WebViewNavigationAction.navigate);

      expect(evaluateWebViewNavigationDecision('tel:0901234567'), WebViewNavigationAction.launchExternal);
      expect(evaluateWebViewNavigationDecision('mailto:support@360.org.vn'), WebViewNavigationAction.launchExternal);
      expect(evaluateWebViewNavigationDecision('sms:+84901234567'), WebViewNavigationAction.launchExternal);

      expect(evaluateWebViewNavigationDecision('zalo://conversation?id=1'), WebViewNavigationAction.prevent);
      expect(evaluateWebViewNavigationDecision('intent://scan/#Intent;end'), WebViewNavigationAction.prevent);
      expect(evaluateWebViewNavigationDecision(''), WebViewNavigationAction.prevent);
    });

    test('shouldIgnoreWebResourceError ignores -10 / ERR_UNKNOWN_URL_SCHEME and non-http schemes', () {
      expect(
        shouldIgnoreWebResourceError(
          errorCode: -10,
          description: 'net::ERR_UNKNOWN_URL_SCHEME',
          url: 'zalo://open',
        ),
        isTrue,
      );
      expect(
        shouldIgnoreWebResourceError(
          errorCode: -1,
          description: 'ERR_UNKNOWN_URL_SCHEME',
        ),
        isTrue,
      );
      expect(
        shouldIgnoreWebResourceError(
          errorCode: -2,
          description: 'net::ERR_NAME_NOT_RESOLVED',
          url: 'https://vuahethong.net/web',
        ),
        isFalse,
      );
    });

    test('isOdooTechnicalRedirectForPop detects auth/login/mail_view technical hops', () {
      expect(isOdooTechnicalRedirectForPop('http://192.168.1.100:1900/api/v1/mobile/web/auth?token=abc'), isTrue);
      expect(isOdooTechnicalRedirectForPop('http://192.168.1.100:1900/web/login?redirect=/mail/view'), isTrue);
      expect(isOdooTechnicalRedirectForPop('http://192.168.1.100:1900/web/database/selector'), isTrue);
      expect(isOdooTechnicalRedirectForPop('http://192.168.1.100:1900/mail/view?model=sale.order&res_id=1500'), isTrue);

      expect(isOdooTechnicalRedirectForPop('http://192.168.1.100:1900/odoo/sale.order/1500'), isFalse);
      expect(isOdooTechnicalRedirectForPop('http://192.168.1.100:1900/web#id=1500&model=sale.order'), isFalse);
    });

    test('normalizeWebViewUrlForComparison ignores db query param and trailing slash/hash', () {
      expect(
        normalizeWebViewUrlForComparison('http://192.168.1.100:1900/odoo/sale.order/1500/?db=vcloud_test_v19#'),
        'http://192.168.1.100:1900/odoo/sale.order/1500',
      );
    });
  });

  group('BUG-16: Safe Casts against Odoo boolean false', () {
    test('ChatV2InboxItem.fromJson handles Odoo false values without TypeError', () {
      final item = ChatV2InboxItem.fromJson(<String, dynamic>{
        'id': 500,
        'subject': false,
        'record_name': false,
        'model': false,
        'res_id': false,
        'body': false,
        'author_name': false,
        'author_avatar': false,
        'message_type': false,
        'attachments': [
          <String, dynamic>{
            'id': 9,
            'name': false,
            'mimetype': false,
            'file_size': false,
            'url': false,
          },
        ],
      });

      expect(item.id, 500);
      expect(item.subject, '');
      expect(item.recordName, '');
      expect(item.model, '');
      expect(item.resId, 0);
      expect(item.body, '');
      expect(item.authorName, 'System');
      expect(item.authorAvatar, isNull);
      expect(item.messageType, 'comment');
      expect(item.attachments.single.name, '');
      expect(item.attachments.single.mimetype, '');
      expect(item.attachments.single.url, '');
    });

    testWidgets('ProfileScreen renders cleanly when userMetadata contains Odoo false', (tester) async {
      const userWithFalse = AuthUser(
        id: '42',
        email: 'tan@360.org.vn',
        userMetadata: <String, dynamic>{
          'display_name': false,
          'function': false,
          'job_title': false,
          'role': false,
          'company': false,
          'company_name': false,
          'partner_company_name': false,
          'is_portal': true,
        },
      );

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _StubAuthController(userWithFalse)),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('tan'), findsOneWidget);
      expect(find.text('Khách hàng · Khách hàng cá nhân'), findsOneWidget);
    });
  });

  group('BUG-19: Internal Odoo Link Routing & Inbox Record Action', () {
    test('resolveInternalAppRoute routes Odoo 19 helpdesk.ticket to /tickets/<id> and same-host Odoo URLs to /webview', () {
      const base = 'http://192.168.1.100:1900';

      expect(
        ChatV2MessageItem.resolveInternalAppRoute(
          '$base/odoo/helpdesk.ticket/88',
          baseUrl: base,
        ),
        '/tickets/88',
      );
      expect(
        ChatV2MessageItem.resolveInternalAppRoute(
          '/odoo/helpdesk.ticket/89',
          baseUrl: base,
        ),
        '/tickets/89',
      );

      final soRoute = ChatV2MessageItem.resolveInternalAppRoute(
        '$base/odoo/sale.order/1500',
        baseUrl: base,
      );
      expect(soRoute, isNotNull);
      expect(soRoute, startsWith('/webview?'));
      expect(Uri.parse(soRoute!).queryParameters['url'], '/odoo/sale.order/1500');

      final mailViewRoute = ChatV2MessageItem.resolveInternalAppRoute(
        '$base/mail/view?model=sale.order&res_id=1500',
        baseUrl: base,
      );
      expect(mailViewRoute, isNotNull);
      expect(mailViewRoute, startsWith('/webview?'));
      expect(
        Uri.parse(mailViewRoute!).queryParameters['url'],
        '/mail/view?model=sale.order&res_id=1500',
      );

      final webFragRoute = ChatV2MessageItem.resolveInternalAppRoute(
        '$base/web#id=42&model=res.partner&view_type=form',
        baseUrl: base,
      );
      expect(webFragRoute, isNotNull);
      expect(webFragRoute, startsWith('/webview?'));
      expect(
        Uri.parse(webFragRoute!).queryParameters['url'],
        '/web#id=42&model=res.partner&view_type=form',
      );

      expect(
        ChatV2MessageItem.resolveInternalAppRoute(
          'https://external-site.com/odoo/sale.order/1500',
          baseUrl: base,
        ),
        isNull,
      );
    });

    testWidgets('ChatV2InboxTab renders "Xem chứng từ" for non-channel record items', (tester) async {
      const state = ChatV2InboxState(
        isLoading: false,
        inboxItems: [
          ChatV2InboxItem(
            id: 1,
            subject: 'Đơn hàng SO1033',
            recordName: 'SO1033',
            model: 'sale.order',
            resId: 1500,
            body: '<p>Đã xác nhận đơn hàng</p>',
            authorName: 'Hệ thống',
          ),
          ChatV2InboxItem(
            id: 2,
            subject: 'Tin nhắn kênh',
            recordName: 'General',
            model: 'discuss.channel',
            resId: 12,
            channelId: 12,
            body: '<p>Hello</p>',
            authorName: 'An',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatV2InboxControllerProvider.overrideWith(() => _StubInboxController(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatV2InboxTab(tabType: ChatV2InboxTabType.inbox),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Xem chứng từ'), findsOneWidget);
      expect(find.text('Vào trò chuyện'), findsOneWidget);
    });
  });

  group('BUG-14 Frontend: Timesheet delete endpoint & cache eviction', () {
    test('TimesheetRepository.delete calls /api/v1/mobile/timesheet/<id> and evicts _cachedEntries', () async {
      TimesheetRepository.clearCache();
      final client = _StubOdooClient()
        ..getResult = [
          <String, dynamic>{
            'id': 42,
            'name': 'Fix WebView',
            'unit_amount': 1.0,
            'date': '2026-11-26',
            'employee_id': [1, 'Tân'],
            'project_id': [2, 'VCloud'],
          },
          <String, dynamic>{
            'id': 43,
            'name': 'Review PR',
            'unit_amount': 0.5,
            'date': '2026-11-26',
            'employee_id': [1, 'Tân'],
            'project_id': [2, 'VCloud'],
          },
        ]
        ..deleteResult = <String, dynamic>{'status': 'deleted'};

      final repo = TimesheetRepository(client: client);
      final streamEntries = await repo.watchRecent(limit: 100).firstWhere((list) => list.length == 2);
      expect(streamEntries.map((e) => e.id).toList(), ['42', '43']);

      await repo.delete('42');
      expect(client.calls, contains('DELETE /api/v1/mobile/timesheet/42'));
      expect(
        client.calls.any((c) => c.contains('account.analytic.line')),
        isFalse,
      );

      // Re-subscribing emits cached entries without deleted '42' first
      client.getResult = [
        <String, dynamic>{
          'id': 43,
          'name': 'Review PR',
          'unit_amount': 0.5,
          'date': '2026-11-26',
          'employee_id': [1, 'Tân'],
          'project_id': [2, 'VCloud'],
        },
      ];
      final afterDelete = await repo.watchRecent().first;
      expect(afterDelete.map((e) => e.id).toList(), ['43']);
      TimesheetRepository.clearCache();
    });
  });

  group('BUG-15: Ticket safe casts against Odoo false & teamId preservation', () {
    test('TicketRepository parses Odoo false fields safely and populates teamId', () async {
      final client = _StubOdooClient()
        ..getResult = <String, dynamic>{
          'id': 123,
          'name': 'Lỗi đồng bộ',
          'description': false,
          'create_date': false,
          'write_date': false,
          'priority': false,
          'team_name': false,
          'partner_name': false,
          'user_name': false,
          'team_id': [3, 'IT Support'],
          'partner_id': false,
          'user_id': false,
        };

      final repo = TicketRepository(client: client);
      final ticket = await repo.one('123');

      expect(ticket.id, '123');
      expect(ticket.title, 'Lỗi đồng bộ');
      expect(ticket.description, isNull);
      expect(ticket.priority, TicketPriority.p3);
      expect(ticket.teamId, 3);
      expect(ticket.category, 'IT Support');
      expect(ticket.partnerName, isNull);
      expect(ticket.assignedUserName, isNull);
    });

    test('TicketRepository.update sends integer team_id from teamId or category', () async {
      final client = _StubOdooClient()
        ..postResult = <String, dynamic>{'status': 'updated'}
        ..getResult = <String, dynamic>{
          'id': 123,
          'name': 'Updated',
          'team_id': [5, 'ERP Team'],
        };

      final repo = TicketRepository(client: client);
      final updated = await repo.update('123', teamId: 5);

      expect(client.calls, contains('POST /api/v1/mobile/ticket/123/update'));
      final body = client.bodies.single as Map<String, dynamic>;
      expect(body['team_id'], 5);
      expect(updated.teamId, 5);
      expect(updated.category, 'ERP Team');
    });
  });
}
