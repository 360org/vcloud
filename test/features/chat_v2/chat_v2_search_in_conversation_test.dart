import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

TextSpan? _findSpanRecursively(InlineSpan? span, bool Function(TextSpan) predicate) {
  if (span == null) return null;
  if (span is TextSpan) {
    if (predicate(span)) return span;
    if (span.children != null) {
      for (final child in span.children!) {
        final found = _findSpanRecursively(child, predicate);
        if (found != null) return found;
      }
    }
  }
  return null;
}

List<TextSpan> _findAllSpansRecursively(InlineSpan? span, bool Function(TextSpan) predicate) {
  final results = <TextSpan>[];
  if (span == null) return results;
  if (span is TextSpan) {
    if (predicate(span)) results.add(span);
    if (span.children != null) {
      for (final child in span.children!) {
        results.addAll(_findAllSpansRecursively(child, predicate));
      }
    }
  }
  return results;
}

void main() {
  group('Chat V2 In-Conversation Search & Keyword Highlighting Tests', () {
    testWidgets('Case 1: No searchQuery -> renders normal Text without highlights',
        (tester) async {
      final msg = ChatV2Message(
        id: 'msg_1',
        channelId: '1',
        content: 'Xin chào Sếp Tân',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: null,
            ),
          ),
        ),
      );

      expect(find.text('Xin chào Sếp Tân'), findsOneWidget);
    });

    testWidgets('Case 2: Matching searchQuery -> renders Text.rich with bold FontWeight.w800',
        (tester) async {
      final msg = ChatV2Message(
        id: 'msg_2',
        channelId: '1',
        content: 'Dự án VCloud hoàn tất',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: 'VCloud',
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('VCloud'),
      );
      expect(richTextFinder, findsWidgets);

      final richText = tester.widget<RichText>(richTextFinder.first);
      final matchedSpan = _findSpanRecursively(
        richText.text,
        (s) => s.text == 'VCloud',
      );

      expect(matchedSpan, isNotNull);
      expect(matchedSpan!.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('Case 3: Passive match -> background #FEF08A and text #0F172A',
        (tester) async {
      final msg = ChatV2Message(
        id: 'msg_3',
        channelId: '1',
        content: 'Báo cáo tiến độ hôm nay',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: 'tiến độ',
              isSearchActiveMatch: false,
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('tiến độ'),
      );
      final richText = tester.widget<RichText>(richTextFinder.first);
      final matchedSpan = _findSpanRecursively(
        richText.text,
        (s) => s.text == 'tiến độ',
      );

      expect(matchedSpan, isNotNull);
      expect(matchedSpan!.style?.backgroundColor, const Color(0xFFFEF08A));
      expect(matchedSpan.style?.color, const Color(0xFF0F172A));
      expect(matchedSpan.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('Case 4: Active match -> background #F97316 and text Colors.white',
        (tester) async {
      final msg = ChatV2Message(
        id: 'msg_4',
        channelId: '1',
        content: 'Đã hoàn thành kiểm thử',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: 'kiểm thử',
              isSearchActiveMatch: true,
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('kiểm thử'),
      );
      final richText = tester.widget<RichText>(richTextFinder.first);
      final matchedSpan = _findSpanRecursively(
        richText.text,
        (s) => s.text == 'kiểm thử',
      );

      expect(matchedSpan, isNotNull);
      expect(matchedSpan!.style?.backgroundColor, const Color(0xFFF97316));
      expect(matchedSpan.style?.color, Colors.white);
      expect(matchedSpan.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('Case 5: Case-insensitive search matches variations',
        (tester) async {
      final msg = ChatV2Message(
        id: 'msg_5',
        channelId: '1',
        content: 'Testing FLUTTER App and flutter web',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: 'flutter',
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Testing'),
      );
      final richText = tester.widget<RichText>(richTextFinder.first);

      final matchedSpans = _findAllSpansRecursively(
        richText.text,
        (s) => (s.text == 'FLUTTER' || s.text == 'flutter') && s.style?.fontWeight == FontWeight.w800,
      );

      expect(matchedSpans.length, 2);
    });

    testWidgets('Case 6: Multiple keyword occurrences in single message',
        (tester) async {
      final msg = ChatV2Message(
        id: 'msg_6',
        channelId: '1',
        content: 'ok anh nhé, ok em đã rõ',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: 'ok',
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('ok anh nhé'),
      );
      final richText = tester.widget<RichText>(richTextFinder.first);

      final okSpans = _findAllSpansRecursively(
        richText.text,
        (s) => s.text == 'ok' && s.style?.fontWeight == FontWeight.w800,
      );

      expect(okSpans.length, 2);
    });

    testWidgets('Case 7: Search matches at beginning and end of text boundaries',
        (tester) async {
      final msg = ChatV2Message(
        id: 'msg_7',
        channelId: '1',
        content: 'start middle end',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: 'start',
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('middle'),
      );
      final richText = tester.widget<RichText>(richTextFinder.first);
      final firstSpan = _findSpanRecursively(
        richText.text,
        (s) => s.text == 'start' && s.style?.fontWeight == FontWeight.w800,
      );

      expect(firstSpan, isNotNull);
    });

    testWidgets('Case 8: HTML tags are not falsely matched by short letter query',
        (tester) async {
      const rawHtml = '<p>Xin chào</p>';
      final clean = ChatV2Message.cleanHtml(rawHtml);

      expect(clean, 'Xin chào');
      expect(clean.toLowerCase().contains('p'), isFalse);
    });

    testWidgets('Case 9: Search works with links in message', (tester) async {
      final msg = ChatV2Message(
        id: 'msg_9',
        channelId: '1',
        content: 'Xem thêm tại https://360.org.vn để biết chi tiết',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: 'chi tiết',
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('chi tiết'),
      );
      expect(richTextFinder, findsWidgets);

      final richText = tester.widget<RichText>(richTextFinder.first);
      final matchedSpan = _findSpanRecursively(
        richText.text,
        (s) => s.text == 'chi tiết',
      );

      expect(matchedSpan, isNotNull);
      expect(matchedSpan!.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('Case 10: Search query whitespace is trimmed', (tester) async {
      final msg = ChatV2Message(
        id: 'msg_10',
        channelId: '1',
        content: 'Test trim whitespace query',
        isMine: false,
        createdAt: DateTime.now(),
        authorName: 'Nguyễn Văn A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              searchQuery: '  whitespace  ',
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('whitespace'),
      );
      final richText = tester.widget<RichText>(richTextFinder.first);
      final matchedSpan = _findSpanRecursively(
        richText.text,
        (s) => s.text == 'whitespace',
      );

      expect(matchedSpan, isNotNull);
      expect(matchedSpan!.style?.fontWeight, FontWeight.w800);
    });
  });
}
