import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/chat/application/unread_chat_controller.dart';
import 'package:vcloud/features/chat/data/chat_repository.dart';
import 'package:vcloud/shared/models/conversation.dart';

/// Fake OdooApiClient simulating Odoo 17.0 JSON-RPC / REST endpoints response.
class FakeOdooApiClient implements OdooApiClient {
  final Map<String, dynamic> lastPostPayloads = {};
  final List<String> calledEndpoints = [];

  @override
  OdooSession? get session => OdooSession(
        accessToken: 'test_token',
        uid: 102,
        db: 'demo-17',
        login: 'chau@w360s.com',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        baseUrl: 'http://localhost:8069',
      );

  @override
  Future<dynamic> get(
    String path, {
    bool auth = true,
    Map<String, Object?> query = const {},
  }) async {
    calledEndpoints.add(path);
    if (path == '/api/v1/mobile/chat/channels') {
      return [
        {
          "id": 45,
          "name": "W360S CORP General",
          "channel_type": "group",
          "unread_count": 3,
          "member_count": 5,
          "has_avatar": false,
          "last_message": "Đã gửi báo cáo tài chính quý II rồi sếp.",
          "last_message_date": "2026-08-13 01:14:26",
          "last_message_id": 1009,
          "description": false,
        },
        {
          "id": 46,
          "name": "Tân Nhật",
          "channel_type": "chat",
          "unread_count": 0,
          "member_count": 2,
          "has_avatar": true,
          "avatar_url": "/api/v1/mobile/avatar/res.users/103",
          "last_message": "Dạ em đã kiểm tra xong.",
          "last_message_date": "2026-08-13 01:20:00",
          "last_message_id": 1010,
        }
      ];
    }
    if (path.contains('/messages')) {
      return {
        "messages": [
          {
            "id": 1010,
            "body": "Nội dung tin nhắn văn bản mới",
            "author_id": [103, "Tân Nhật"],
            "author_avatar": false,
            "date": "2026-08-13 01:25:08",
            "is_read": true,
            "attachment_ids": [1289],
            "attachments": [
              {
                "id": 1289,
                "name": "invoice_capture.jpg",
                "mimetype": "image/jpeg",
                "file_size": 12450,
                "download_url": "/api/v1/mobile/attachments/1289/download"
              }
            ]
          }
        ],
        "count": 1
      };
    }
    if (path.contains('/api/v1/mobile/users/search')) {
      return [];
    }
    return {};
  }

  @override
  Future<dynamic> post(
    String path, {
    bool auth = true,
    Object? body,
    Map<String, Object?> query = const {},
  }) async {
    calledEndpoints.add(path);
    if (body is Map<String, dynamic>) {
      lastPostPayloads[path] = body;
    }

    if (path == '/api/v1/mobile/chat/messages') {
      final map = body as Map<String, dynamic>;
      final attachmentIds = map['attachment_ids'] as List?;
      return {
        "status": "success",
        "data": {
          "id": 1010,
          "body": map['body'] ?? "",
          "author_id": 103,
          "author_name": "Tân Nhật",
          "create_date": "2026-08-13 01:25:08",
          "attachment_ids": attachmentIds ?? [],
          "attachments": attachmentIds != null && attachmentIds.isNotEmpty
              ? [
                  {
                    "id": attachmentIds.first,
                    "name": "image_1.png",
                    "mimetype": "image/png",
                    "file_size": 245600
                  }
                ]
              : []
        }
      };
    }

    if (path.contains('/mark-read')) {
      return {
        "status": "success",
        "channel_id": "45",
        "unread_count": 0
      };
    }

    if (path == '/api/v1/mobile/chat/groups') {
      final map = body as Map<String, dynamic>;
      return {
        "status": "success",
        "channel": {
          "id": 47,
          "name": map['name'] ?? "Group Chat",
          "channel_type": "group"
        }
      };
    }

    return {"status": "success"};
  }

  @override
  String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'http://localhost:8069$path';
  }

  @override
  String authenticatedUrl(String path, {String? accessToken}) {
    final url = absoluteUrl(path);
    final token = accessToken ?? 'test_token';
    return url.contains('?') ? '$url&access_token=$token' : '$url?access_token=$token';
  }

  @override
  void registerPartnerUserMapping(Object? partnerId, Object? userId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake MobileAttachmentRepository for upload testing.
class FakeMobileAttachmentRepository implements MobileAttachmentRepository {
  final List<MobileAttachmentUpload> uploadedItems = [];

  @override
  Future<MobileAttachment> upload(MobileAttachmentUpload item) async {
    uploadedItems.add(item);
    return MobileAttachment(
      id: 1289,
      attachmentId: 1289,
      name: item.filename,
      mimetype: item.mimetype,
      fileSize: item.bytes.length,
      url: 'http://localhost:8069/web/content/1289/${item.filename}',
    );
  }

  @override
  Future<MobileAttachment> one(int attachmentId) async {
    return MobileAttachment(
      id: attachmentId,
      attachmentId: attachmentId,
      name: 'invoice_capture.jpg',
      mimetype: 'image/jpeg',
      fileSize: 12450,
      downloadUrl: '/api/v1/mobile/attachments/$attachmentId/download',
    );
  }

  @override
  Future<Uint8List> fetchBytes(int attachmentId, {String? accessToken}) async {
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider channel for local attachment cache
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return '/tmp';
    },
  );

  late FakeOdooApiClient fakeClient;
  late FakeMobileAttachmentRepository fakeAttachmentRepo;
  late ChatRepository chatRepository;

  setUp(() {
    fakeClient = FakeOdooApiClient();
    fakeAttachmentRepo = FakeMobileAttachmentRepository();
    chatRepository = ChatRepository(
      client: fakeClient,
      attachmentRepository: fakeAttachmentRepo,
    );
  });

  group('Enterprise Chat Unit Test Suite (Odoo 17 & Riverpod Integration)', () {
    test('QA-CHAT-01: Safe Parsing of ConversationSummary from Odoo JSON (TypeError Bypass)', () {
      final odooJson = {
        "id": 45,
        "name": "W360S CORP General",
        "channel_type": "group",
        "unread_count": 3,
        "member_count": 5,
        "has_avatar": false,
        "last_message": "Đã gửi báo cáo tài chính quý II rồi sếp.",
        "last_message_date": "2026-08-13 01:14:26",
        "last_message_id": 1009,
        "description": false,
      };

      final summary = ConversationSummary.fromOdooChatChannel(odooJson);

      expect(summary.id, equals('45'));
      expect(summary.title, equals('W360S CORP General'));
      expect(summary.unreadCount, equals(3));
      expect(summary.description, isNull);
      expect(summary.avatarUrl, isNull);
    });

    test('QA-CHAT-02: Mark-as-read Reactivity and Unread Count Sync in Riverpod State', () async {
      final notifier = UnreadChatNotifier(client: fakeClient);

      // Pre-set state for test
      notifier.state = const UnreadChatState(
        totalUnreadCount: 3,
        channelUnreadCounts: {45: 3, 46: 0},
      );
      expect(notifier.state.totalUnreadCount, equals(3));
      expect(notifier.state.channelUnreadCounts[45], equals(3));

      // Trigger markAsRead for channel 45
      await notifier.markAsRead(45);

      // State optimistic & server sync update to 0
      expect(notifier.state.channelUnreadCounts[45], equals(0));
      expect(notifier.state.totalUnreadCount, equals(0));
      expect(fakeClient.calledEndpoints, contains('/api/v1/mobile/chat/channels/45/mark-read'));

      notifier.dispose();
    });

    test('QA-CHAT-03: Send Message with Attachment IDs Payload Verification', () async {
      final msg = await chatRepository.sendMessage('45', 'Tin nhắn kèm ảnh');

      expect(msg.id, equals('1010'));
      expect(fakeClient.calledEndpoints, contains('/api/v1/mobile/chat/messages'));
      expect(fakeClient.lastPostPayloads['/api/v1/mobile/chat/messages'], equals({
        'channel_id': 45,
        'body': 'Tin nhắn kèm ảnh',
      }));
    });

    test('QA-CHAT-04: Multi-Attachment Upload and Message Post Pipeline', () async {
      final upload = MobileAttachmentUpload(
        filename: 'invoice_capture.jpg',
        bytes: Uint8List.fromList([10, 20, 30]),
        mimetype: 'image/jpeg',
      );

      final result = await chatRepository.uploadAttachment('45', upload);

      expect(result.attachmentId, equals(1289));
      expect(fakeAttachmentRepo.uploadedItems.length, equals(1));
      expect(fakeAttachmentRepo.uploadedItems.first.filename, equals('invoice_capture.jpg'));
      expect(fakeClient.lastPostPayloads['/api/v1/mobile/chat/messages'], equals({
        'channel_id': 45,
        'body': 'invoice_capture.jpg',
        'attachment_ids': [1289],
      }));
    });

    test('QA-CHAT-05: Create Chat Group Endpoint Pipeline', () async {
      final channelId = await chatRepository.createGroup('Đội dự án V_Cloud', ['102', '103', '104']);

      expect(channelId, equals('47'));
      expect(fakeClient.lastPostPayloads['/api/v1/mobile/chat/groups'], equals({
        'name': 'Đội dự án V_Cloud',
        'partner_ids': [102, 103, 104],
      }));
    });
  });
}
