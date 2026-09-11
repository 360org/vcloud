import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

Widget _wrapWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: false,
      splashFactory: NoSplash.splashFactory,
    ),
    home: Scaffold(body: child),
  );
}

const mockMembers = [
  ChatV2Member(id: '1', name: 'Admin', email: 'admin@360.org.vn'),
  ChatV2Member(id: '2', name: 'Bùi Tuấn Kiệt', email: 'kiet@360.org.vn'),
  ChatV2Member(id: '3', name: 'Lê Bá Châu', email: 'chau@360.org.vn'),
  ChatV2Member(id: '4', name: 'Đặng Đình Đức', email: 'duc@360.org.vn'),
  ChatV2Member(id: '5', name: 'Võ Thị Sáu', email: 'sau@360.org.vn'),
  ChatV2Member(id: '6', name: "O'Connor", email: 'oconnor@360.org.vn'),
  ChatV2Member(id: '7', name: 'Trần Văn A-B', email: 'ab@360.org.vn'),
  ChatV2Member(id: '8', name: 'Nguyễn Văn A', email: 'nva@360.org.vn'),
  ChatV2Member(id: '9', name: 'Nguyễn Văn', email: 'nv@360.org.vn'),
  ChatV2Member(id: '99', name: 'Tôi', email: 'me@360.org.vn', isMe: true),
];

List<String> _extractMentionSpans(WidgetTester tester) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  final spans = <String>[];
  for (final rt in richTexts) {
    rt.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) {
        final t = span.text!.trim();
        if (t.startsWith('@') && span.style?.fontWeight == FontWeight.w700) {
          spans.add(t);
        }
      }
      return true;
    });
  }
  return spans;
}

void main() {
  group('Ca 1: Mention ở các vị trí đặc biệt', () {
    testWidgets('1.1 @ ở đầu dòng kích hoạt popup gợi ý và gửi đúng partnerIds', (tester) async {
      String? sentText;
      List<int>? sentPartnerIds;
      final controller = TextEditingController();

      await tester.pumpWidget(
        _wrapWidget(
          ChatV2InputBar(
            isGroup: true,
            controller: controller,
            channelMembers: mockMembers,
            onSend: (text, {partnerIds, mentionedPartners}) async {
              sentText = text;
              sentPartnerIds = partnerIds;
            },
          ),
        ),
      );

      // Gõ @ ở đầu dòng
      controller.value = const TextEditingValue(
        text: '@',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();

      // Kiểm tra popup gợi ý xuất hiện (không chứa isMe=true)
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Đặng Đình Đức'), findsOneWidget);
      expect(find.text('Tôi'), findsNothing);

      // Chọn Admin
      await tester.tap(find.text('Admin'));
      await tester.pump();

      expect(controller.text, '@Admin ');
      expect(find.text('@tag'), findsNothing); // popup đã đóng

      // Gửi
      final sendBtn = find.byIcon(LucideIcons.send);
      await tester.tap(sendBtn, warnIfMissed: false);
      await tester.pump();

      expect(sentText, '@Admin');
      expect(sentPartnerIds, [1]);
    });

    testWidgets('1.2 @ giữa câu và sau dấu xuống dòng kích hoạt gợi ý', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        _wrapWidget(
          ChatV2InputBar(
            isGroup: true,
            controller: controller,
            channelMembers: mockMembers,
            onSend: (text, {partnerIds, mentionedPartners}) async {},
          ),
        ),
      );

      // Giữa câu: "Chào @"
      controller.value = const TextEditingValue(
        text: 'Chào @',
        selection: TextSelection.collapsed(offset: 6),
      );
      await tester.pump();
      expect(find.text('Bùi Tuấn Kiệt'), findsOneWidget);

      // Chọn Bùi Tuấn Kiệt
      await tester.tap(find.text('Bùi Tuấn Kiệt'));
      await tester.pump();
      expect(controller.text, 'Chào @Bùi Tuấn Kiệt ');

      // Sau dấu xuống dòng: "\n@"
      controller.value = TextEditingValue(
        text: '${controller.text}\n@',
        selection: TextSelection.collapsed(offset: controller.text.length + 2),
      );
      await tester.pump();
      expect(find.text('Lê Bá Châu'), findsOneWidget);

      // Chọn Lê Bá Châu
      await tester.tap(find.text('Lê Bá Châu'));
      await tester.pump();
      expect(controller.text, 'Chào @Bùi Tuấn Kiệt \n@Lê Bá Châu ');
    });

    testWidgets('1.3 ChatV2MessageItem render mention trước dấu chấm phẩy chính xác', (tester) async {
      const msg = ChatV2Message(
        id: '101',
        channelId: '1',
        content: 'Chào @Admin, và @Đặng Đình Đức. Bạn có khỏe không?',
        authorName: 'Sếp Tân',
        isMine: false,
      );

      await tester.pumpWidget(_wrapWidget(const ChatV2MessageItem(message: msg)));

      final mentions = _extractMentionSpans(tester);
      expect(mentions, contains('@Admin'));
      expect(mentions, contains('@Đặng Đình Đức'));
    });
  });

  group('Ca 2: Xóa Mention (Backspace & Deletion)', () {
    testWidgets('2.1 Xóa một phần token Mention không gửi nhầm partnerId', (tester) async {
      String? sentText;
      List<int>? sentPartnerIds;
      final controller = TextEditingController();

      await tester.pumpWidget(
        _wrapWidget(
          ChatV2InputBar(
            isGroup: true,
            controller: controller,
            channelMembers: mockMembers,
            onSend: (text, {partnerIds, mentionedPartners}) async {
              sentText = text;
              sentPartnerIds = partnerIds;
            },
          ),
        ),
      );

      // Gõ @nguyen
      controller.value = const TextEditingValue(
        text: '@nguyen',
        selection: TextSelection.collapsed(offset: 7),
      );
      await tester.pump();

      // Chọn "Nguyễn Văn A" (id: 8)
      await tester.tap(find.text('Nguyễn Văn A'));
      await tester.pump();
      expect(controller.text, '@Nguyễn Văn A ');

      // Giả lập người dùng Backspace xóa chữ 'A ' -> còn lại '@Nguyễn Văn '
      controller.value = const TextEditingValue(
        text: '@Nguyễn Văn ',
        selection: TextSelection.collapsed(offset: 12),
      );
      await tester.pump();

      // Nhấn gửi
      final sendBtn = find.byIcon(LucideIcons.send);
      await tester.tap(sendBtn, warnIfMissed: false);
      await tester.pump();

      // Kiểm tra: Vì '@Nguyễn Văn A' không còn nguyên vẹn trong text, không được gửi partnerId của Nguyễn Văn A (8)
      // Và cũng không tự gán nhầm cho Nguyễn Văn (9) vì chưa từng chọn 9
      expect(sentText, '@Nguyễn Văn');
      expect(sentPartnerIds, isNull);
    });
  });

  group('Ca 3: Nhiều Mention trong 1 tin nhắn', () {
    testWidgets('3.1 Gửi 3 mention liên tiếp tracking đủ partnerIds và render đúng', (tester) async {
      String? sentText;
      List<int>? sentPartnerIds;
      final controller = TextEditingController();

      await tester.pumpWidget(
        _wrapWidget(
          ChatV2InputBar(
            isGroup: true,
            controller: controller,
            channelMembers: mockMembers,
            onSend: (text, {partnerIds, mentionedPartners}) async {
              sentText = text;
              sentPartnerIds = partnerIds;
            },
          ),
        ),
      );

      // 1. Chọn Admin
      controller.value = const TextEditingValue(text: '@ad', selection: TextSelection.collapsed(offset: 3));
      await tester.pump();
      await tester.tap(find.text('Admin'));
      await tester.pump();

      // 2. Chọn Bùi Tuấn Kiệt (tìm không dấu: @kiet)
      controller.value = TextEditingValue(text: '${controller.text}@kiet', selection: TextSelection.collapsed(offset: controller.text.length + 5));
      await tester.pump();
      await tester.tap(find.text('Bùi Tuấn Kiệt'));
      await tester.pump();

      // 3. Chọn Lê Bá Châu (tìm không dấu: @chau)
      controller.value = TextEditingValue(text: '${controller.text}@chau', selection: TextSelection.collapsed(offset: controller.text.length + 5));
      await tester.pump();
      await tester.tap(find.text('Lê Bá Châu'));
      await tester.pump();

      expect(controller.text, '@Admin @Bùi Tuấn Kiệt @Lê Bá Châu ');

      // Gửi
      final sendBtn = find.byIcon(LucideIcons.send);
      await tester.tap(sendBtn, warnIfMissed: false);
      await tester.pump();

      expect(sentText, '@Admin @Bùi Tuấn Kiệt @Lê Bá Châu');
      expect(sentPartnerIds, [1, 2, 3]);

      // Kiểm tra render trên MessageItem
      final msg = ChatV2Message(
        id: '201',
        channelId: '1',
        content: sentText!,
        partnerIds: sentPartnerIds!,
      );

      await tester.pumpWidget(_wrapWidget(ChatV2MessageItem(message: msg)));

      final mentions = _extractMentionSpans(tester);
      expect(mentions, ['@Admin', '@Bùi Tuấn Kiệt', '@Lê Bá Châu']);
    });
  });

  group('Ca 4: Tên tiếng Việt có dấu đầy đủ & ký tự lạ', () {
    testWidgets('4.1 Tìm kiếm và Mention tên tiếng Việt phức tạp và ký tự đặc biệt', (tester) async {
      String? sentText;
      List<int>? sentPartnerIds;
      final controller = TextEditingController();

      await tester.pumpWidget(
        _wrapWidget(
          ChatV2InputBar(
            isGroup: true,
            controller: controller,
            channelMembers: mockMembers,
            onSend: (text, {partnerIds, mentionedPartners}) async {
              sentText = text;
              sentPartnerIds = partnerIds;
            },
          ),
        ),
      );

      // Tìm O'Connor bằng "@o'"
      controller.value = const TextEditingValue(text: "@o'", selection: TextSelection.collapsed(offset: 3));
      await tester.pump();
      expect(find.text("O'Connor"), findsOneWidget);
      await tester.tap(find.text("O'Connor"));
      await tester.pump();

      // Tìm Trần Văn A-B bằng "@trần"
      controller.value = TextEditingValue(text: '${controller.text}@trần', selection: TextSelection.collapsed(offset: controller.text.length + 5));
      await tester.pump();
      expect(find.text('Trần Văn A-B'), findsOneWidget);
      await tester.tap(find.text('Trần Văn A-B'));
      await tester.pump();

      // Tìm Võ Thị Sáu bằng "@sáu"
      controller.value = TextEditingValue(text: '${controller.text}@sáu', selection: TextSelection.collapsed(offset: controller.text.length + 4));
      await tester.pump();
      expect(find.text('Võ Thị Sáu'), findsOneWidget);
      await tester.tap(find.text('Võ Thị Sáu'));
      await tester.pump();

      expect(controller.text, "@O'Connor @Trần Văn A-B @Võ Thị Sáu ");

      // Gửi
      final sendBtn = find.byIcon(LucideIcons.send);
      await tester.tap(sendBtn, warnIfMissed: false);
      await tester.pump();

      expect(sentPartnerIds, [6, 7, 5]);

      // Render kiểm tra Unicode và ký tự '-' và "'"
      final msg = ChatV2Message(
        id: '301',
        channelId: '1',
        content: sentText!,
      );

      await tester.pumpWidget(_wrapWidget(ChatV2MessageItem(message: msg)));

      final mentions = _extractMentionSpans(tester);
      expect(mentions, ["@O'Connor", '@Trần Văn A-B', '@Võ Thị Sáu']);
    });
  });

  group('Ca 5: Dán văn bản (Paste Action) có chứa ký tự @', () {
    testWidgets('5.1 Dán email hoặc URL chứa @ không làm nhảy popup mention', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        _wrapWidget(
          ChatV2InputBar(
            isGroup: true,
            controller: controller,
            channelMembers: mockMembers,
            onSend: (text, {partnerIds, mentionedPartners}) async {},
          ),
        ),
      );

      // Paste email: "Gửi tới test@360.org.vn ngay" (cursor ở cuối email)
      controller.value = const TextEditingValue(
        text: 'Gửi tới test@360.org.vn ngay',
        selection: TextSelection.collapsed(offset: 24),
      );
      await tester.pump();

      // Popup KHÔNG được xuất hiện
      expect(find.text('@tag'), findsNothing);
      expect(find.text('Admin'), findsNothing);

      // Paste URL: "https://github.com/@360org"
      controller.value = const TextEditingValue(
        text: 'https://github.com/@360org',
        selection: TextSelection.collapsed(offset: 26),
      );
      await tester.pump();

      expect(find.text('@tag'), findsNothing);
      expect(find.text('Admin'), findsNothing);
    });

    testWidgets('5.2 ChatV2MessageItem render URL/Email có @ thành Link bấm được', (tester) async {
      const msg = ChatV2Message(
        id: '401',
        channelId: '1',
        content: 'Vui lòng truy cập https://github.com/@360org để xem code.',
      );

      await tester.pumpWidget(_wrapWidget(const ChatV2MessageItem(message: msg)));

      // Text link xuất hiện
      expect(find.text('https://github.com/@360org'), findsOneWidget);
    });

    testWidgets('5.3 Email không có scheme URL trong văn bản không bị nhầm thành mention', (tester) async {
      const msg = ChatV2Message(
        id: '402',
        channelId: '1',
        content: 'Liên hệ qua contact@mycompany.internal để nhận hỗ trợ.',
      );

      await tester.pumpWidget(_wrapWidget(const ChatV2MessageItem(message: msg)));

      // Kiểm tra không có mention span @mycompany vì trước @ có chữ 'contact'
      final mentions = _extractMentionSpans(tester);
      expect(mentions, isEmpty);
    });
  });
}
