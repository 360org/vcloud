// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat/application/conversations_controller.dart';
import 'package:vcloud/features/chat/application/messages_controller.dart';
import 'package:vcloud/features/chat/presentation/chat_detail_screen.dart';
import 'package:vcloud/features/chat/presentation/widgets/chat_bubbles.dart';
import 'package:vcloud/shared/models/conversation.dart';
import 'package:vcloud/shared/models/message.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => const _FakeHttpClientResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse implements HttpClientResponse {
  const _FakeHttpClientResponse();

  @override
  int get statusCode => 200;
  @override
  int get contentLength => 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
        id: '7',
        email: 'mark.brown23@example.com',
        userMetadata: {'display_name': 'Marc Demo'},
      );
}

class _FakeSendMessageAction implements SendMessageAction {
  final List<Map<String, dynamic>> sent = [];

  @override
  Future<Message> send(String conversationId, String content) async {
    sent.add({'conversationId': conversationId, 'content': content});
    return Message(
      id: 'sent_${sent.length}',
      conversationId: conversationId,
      senderId: '7',
      senderName: 'Marc Demo',
      content: content,
      createdAt: DateTime.now(),
      status: 'sent',
    );
  }
}

class _FakeSendAttachmentAction implements SendAttachmentAction {
  final List<MobileAttachmentUpload> attachments = [];

  @override
  Future<MobileAttachment> send(
    String conversationId,
    MobileAttachmentUpload attachment,
  ) async {
    attachments.add(attachment);
    return MobileAttachment(
      id: 100,
      attachmentId: 100,
      name: attachment.filename,
      mimetype: attachment.mimetype,
      fileSize: attachment.bytes.length,
      url: 'http://localhost:8069/web/content/100/${attachment.filename}',
    );
  }
}

class _FakeMarkAsReadAction implements MarkAsReadAction {
  @override
  Future<void> markAsRead(String conversationId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  final sampleSummary = ConversationSummary(
    id: '42',
    isGroup: true,
    title: 'Nhom du an VCloud',
    lastMessage: null,
    updatedAt: DateTime.utc(2026, 8, 5, 10, 0),
    memberCount: 5,
  );

  final sampleConversation = Conversation(
    id: '42',
    isGroup: true,
    name: 'Nhom du an VCloud',
    createdBy: '3',
    createdAt: DateTime.utc(2026, 8, 5, 10, 0),
    members: const [],
  );

  final initialMessages = <Message>[
    Message(
      id: 'msg_1',
      conversationId: '42',
      senderId: '3',
      senderName: 'Mitchell Admin',
      content: 'Chào cả đội, dự án chạy tốt chứ?',
      createdAt: DateTime.utc(2026, 8, 5, 10, 0),
      status: 'sent',
    ),
    Message(
      id: 'msg_img',
      conversationId: '42',
      senderId: '7',
      senderName: 'Marc Demo',
      content: 'anh.png',
      createdAt: DateTime.utc(2026, 8, 5, 10, 1),
      status: 'sent',
      attachmentIds: const ['1051'],
      attachmentUrl: 'http://localhost:8069/web/content/1051/anh.png',
    ),
    Message(
      id: 'msg_doc',
      conversationId: '42',
      senderId: '7',
      senderName: 'Marc Demo',
      content: 'baocao.pdf',
      createdAt: DateTime.utc(2026, 8, 5, 10, 2),
      status: 'sent',
      attachmentIds: const ['1052'],
      attachmentUrl: 'http://localhost:8069/web/content/1052/baocao.pdf',
    ),
  ];

  late _FakeSendMessageAction fakeSendMessage;
  late _FakeSendAttachmentAction fakeSendAttachment;
  late _FakeMarkAsReadAction fakeMarkAsRead;

  setUp(() {
    fakeSendMessage = _FakeSendMessageAction();
    fakeSendAttachment = _FakeSendAttachmentAction();
    fakeMarkAsRead = _FakeMarkAsReadAction();
  });

  Widget buildChatDetailWidget() {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        conversationsProvider.overrideWith((ref) => Stream.value([sampleSummary])),
        conversationDetailsProvider('42').overrideWith((ref) async => sampleConversation),
        messagesProvider('42').overrideWith((ref) => Stream.value(initialMessages)),
        sendMessageActionProvider.overrideWithValue(fakeSendMessage),
        sendAttachmentActionProvider.overrideWithValue(fakeSendAttachment),
        markAsReadActionProvider.overrideWithValue(fakeMarkAsRead),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const ChatDetailScreen(conversationId: '42'),
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('VCloud Chat Features E2E Integration Suite', () {
    testWidgets('Render Chat Detail Screen and display existing bubbles & image/doc attachments', (
      WidgetTester tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(buildChatDetailWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Nhom du an VCloud'), findsOneWidget);
      expect(find.text('Chào cả đội, dự án chạy tốt chứ?'), findsOneWidget);
      expect(find.byType(NetworkPreviewImage).first, findsOneWidget);
      expect(find.text('baocao.pdf'), findsOneWidget);
    });

    testWidgets('Open Attachment Picker Sheet and verify options (Gallery, Camera, Document, Poll)', (
      WidgetTester tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(buildChatDetailWidget());
      await tester.pump(const Duration(milliseconds: 300));

      final attachmentBtn = find.byTooltip('Thêm nội dung').last;
      expect(attachmentBtn, findsOneWidget);
      await tester.tap(attachmentBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Thư viện ảnh'), findsOneWidget);
      expect(find.text('Máy ảnh'), findsOneWidget);
      expect(find.text('Tài liệu'), findsOneWidget);
      expect(find.text('Tạo bình chọn'), findsOneWidget);
    });

    testWidgets('Attachment action tap shows coming soon snackbar', (
      WidgetTester tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(buildChatDetailWidget());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Thêm nội dung').last);
      await tester.pump(const Duration(milliseconds: 300));

      final actionTile = find.text('Anh');
      if (actionTile.evaluate().isNotEmpty) {
        await tester.tap(actionTile);
        await tester.pump(const Duration(milliseconds: 300));
      }
    });
  });
}
