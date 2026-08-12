import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/ticket/data/ticket_comment_repository.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/shared/models/ticket.dart';

void main() {
  test(
    'TicketRepository strips HTML from ticket title and description',
    () async {
      final repo = TicketRepository(
        client: _FakeOdooApiClient(<String, dynamic>{
          'id': 42,
          'name': '<p>Lá»—i&nbsp;Ä‘Äƒng nháº­p &amp; Ä‘á»“ng bá»™</p>',
          'description':
              '<div>KhÃ´ng vÃ o Ä‘Æ°á»£c app</div><div>Cáº§n kiá»ƒm tra token</div>',
          'create_date': '2026-07-01T08:00:00Z',
          'assign_date': '2026-07-01T08:30:00Z',
          'priority': '2',
          'tags': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'name': 'Odoo'},
            <String, dynamic>{'id': 2, 'name': '<b>ÄÄƒng nháº­p</b>'},
          ],
        }),
      );

      final ticket = await repo.one('42');

      expect(ticket.title, 'Lá»—i Ä‘Äƒng nháº­p & Ä‘á»“ng bá»™');
      expect(
        ticket.description,
        'KhÃ´ng vÃ o Ä‘Æ°á»£c app\nCáº§n kiá»ƒm tra token',
      );
      expect(ticket.tagLabels, <String>['Odoo', 'ÄÄƒng nháº­p']);
    },
  );

  test('TicketCommentRepository strips HTML from comment body', () async {
    final repo = TicketCommentRepository(
      client: _FakeOdooApiClient(<String, dynamic>{
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'author_id': '3',
            'author_name': 'Nguyen An',
            'body':
                '<p>ÄÃ£ kiá»ƒm tra&nbsp;log</p><p>Lá»—i tá»« session &amp; cache</p>',
            'date': '2026-07-01T09:00:00Z',
          },
        ],
      }),
    );

    final comments = await repo.watchByTicket('42').first;

    expect(
      comments.single.content,
      'ÄÃ£ kiá»ƒm tra log\nLá»—i tá»« session & cache',
    );
  });

  test(
    'TicketRepository creates and reads tickets through 360 support API',
    () async {
      final client = _FakeOdooApiClient(
        <String, dynamic>{
          'id': 42,
          'name': 'Ticket mới',
          'description': 'Cần hỗ trợ',
          'create_date': '2026-07-01T08:00:00Z',
          'priority': '1',
        },
        postResponse: <String, dynamic>{'id': 42},
      );
      final repo = TicketRepository(client: client);

      await repo.create(title: 'Ticket mới', description: 'Cần hỗ trợ');

      expect(client.calls, <String>[
        'POST /api/v1/mobile/ticket/create',
        'GET /api/v1/mobile/ticket/42',
      ]);
      expect(client.postBodies.single, containsPair('name', 'Ticket mới'));
      expect(
        client.calls.any((call) => call.contains('helpdesk.ticket')),
        false,
      );
    },
  );

  test(
    'TicketCommentRepository hides the duplicate create description',
    () async {
      final repo = TicketCommentRepository(
        client: _FakeOdooApiClient(<String, dynamic>{
          'description': 'Cannot open the app\nCC email: qa@example.com',
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 7,
              'author_id': '3',
              'author_name': 'Creator',
              'body':
                  '<p>Cannot open the app</p><p>CC email: qa@example.com</p>',
              'date': '2026-07-01T09:00:00Z',
            },
            <String, dynamic>{
              'id': 8,
              'author_id': '4',
              'author_name': 'Agent',
              'body': '<p>We are checking the issue.</p>',
              'date': '2026-07-01T09:05:00Z',
            },
          ],
        }),
      );

      final comments = await repo.watchByTicket('42').first;

      expect(comments, hasLength(1));
      expect(comments.single.id, '8');
      expect(comments.single.content, 'We are checking the issue.');
    },
  );

  test('TicketRepository uploads selected files onto created ticket', () async {
    final client = _FakeOdooApiClient(
      <String, dynamic>{
        'id': 42,
        'name': 'Ticket moi',
        'description': 'Co anh loi',
        'create_date': '2026-07-01T08:00:00Z',
        'priority': '1',
      },
      postResponse: <String, dynamic>{'id': 42},
    );
    final repo = TicketRepository(client: client);

    await repo.create(
      title: 'Ticket moi',
      description: 'Co anh loi',
      attachments: <MobileAttachmentUpload>[
        MobileAttachmentUpload(
          filename: 'loi.png',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimetype: 'image/png',
        ),
      ],
    );

    expect(client.calls, <String>[
      'POST /api/v1/mobile/ticket/create',
      'POST /api/v1/mobile/attachments/upload',
      'GET /api/v1/mobile/ticket/42',
    ]);
    expect(client.postBodies[1], containsPair('res_model', 'helpdesk.ticket'));
    expect(client.postBodies[1], containsPair('res_id', 42));
    expect(client.postBodies[1], containsPair('filename', 'loi.png'));
    expect(client.postBodies[1], containsPair('datas', 'AQID'));
  });

  test('MobileAttachmentRepository reads metadata endpoint', () async {
    final repo = MobileAttachmentRepository(
      client: _FakeOdooApiClient(<String, dynamic>{
        'id': 9,
        'attachment_id': 9,
        'name': 'loi.png',
        'mimetype': 'image/png',
        'file_size': 1024,
        'url': '/web/image/9',
        'download_url': '/web/content/9?download=1',
        'access_token': 'token',
      }),
    );

    final attachment = await repo.one(9);

    expect(attachment.id, 9);
    expect(attachment.mimetype, 'image/png');
    expect(attachment.fileSize, 1024);
    expect(attachment.downloadUrl, '/web/content/9?download=1');
  });

  test('TicketRepository sends contact card through mobile endpoint', () async {
    final client = _FakeOdooApiClient(<String, dynamic>{'ok': true});
    final repo = TicketRepository(client: client);

    await repo.sendContact('42', 7);

    expect(client.calls.single, 'POST /api/v1/mobile/ticket/42/contact');
    expect(client.postBodies.single, <String, dynamic>{'partner_id': 7});
  });

  test('TicketRepository parses attachments and activities from API response', () async {
    final client = _FakeOdooApiClient(<String, dynamic>{
      'id': 42,
      'name': 'Ticket có đính kèm',
      'description': 'Mô tả',
      'create_date': '2026-07-01T08:00:00Z',
      'attachments': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 101,
          'name': 'bao_cao.pdf',
          'mimetype': 'application/pdf',
          'file_size': 204800,
        },
      ],
    });
    final repo = TicketRepository(client: client);

    final ticket = await repo.one('42');
    expect(ticket.attachments.length, 1);
    expect(ticket.attachments.first.name, 'bao_cao.pdf');
    expect(ticket.attachments.first.fileSize, 204800);

    final activitiesClient = _FakeOdooApiClient(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'activity_type_name': 'Email',
        'summary': 'Gửi báo giá',
        'note': '<p>Đã gửi</p>',
        'user_name': 'Nguyen An',
        'create_date': '2026-08-12T09:30:00Z',
      },
    ]);
    final repoAct = TicketRepository(client: activitiesClient);
    final activities = await repoAct.activities('42');
    expect(activities.length, 1);
    expect(activities.first.summary, 'Gửi báo giá');
    expect(activities.first.userName, 'Nguyen An');
  });

  test('TicketRepository watchAssigned passes filter parameters', () async {
    final client = _FakeOdooApiClient(<Map<String, dynamic>>[]);
    final repo = TicketRepository(client: client);

    final stream = repo.watchAssigned(
      filter: const TicketFilter(priority: TicketPriority.p1, teamId: 5),
    );
    await stream.first;

    expect(client.calls.first, 'GET /api/v1/mobile/ticket/list?priority=3&team_id=5');
  });
}

class _FakeOdooApiClient extends OdooApiClient {
  _FakeOdooApiClient(this._response, {this._postResponse})
    : super(baseUrl: 'https://example.test');

  final Object _response;
  final Object? _postResponse;
  final calls = <String>[];
  final postBodies = <Object?>[];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    calls.add('GET $path');
    return _response;
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    calls.add('POST $path');
    postBodies.add(body);
    return _postResponse ?? _response;
  }
}
