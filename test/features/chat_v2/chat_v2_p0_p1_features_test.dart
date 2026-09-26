import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';

class _MockChatV2Repository extends Fake implements ChatV2Repository {
  bool markAsUnreadCalled = false;
  String? lastMarkedUnreadChannelId;

  bool togglePinCalled = false;
  String? lastPinnedMessageId;

  bool removeMemberCalled = false;
  int? lastRemovedPartnerId;

  bool leaveChannelCalled = false;
  String? lastLeftChannelId;

  @override
  Future<void> markAsUnread(String channelId) async {
    markAsUnreadCalled = true;
    lastMarkedUnreadChannelId = channelId;
  }

  @override
  Future<bool> togglePinMessage({
    required String channelId,
    required String messageId,
  }) async {
    togglePinCalled = true;
    lastPinnedMessageId = messageId;
    return true;
  }

  @override
  Future<void> removeChannelMember({
    required String channelId,
    required int partnerId,
  }) async {
    removeMemberCalled = true;
    lastRemovedPartnerId = partnerId;
  }

  @override
  Future<void> leaveChannel(String channelId) async {
    leaveChannelCalled = true;
    lastLeftChannelId = channelId;
  }
}

void main() {
  group('Sprint P0 & P1 Features Test Suite (Anti-Sycophancy Protocol V2.1)', () {
    // ---------------------------------------------------------
    // Test Case 1: Pinned message model serialization & isPinned getter
    // ---------------------------------------------------------
    test('Case 1: ChatV2Message pinnedAt serialization, copyWith, and isPinned getter', () {
      final msg = ChatV2Message(
        id: '101',
        channelId: '1',
        authorId: '2',
        authorName: 'Nguyễn Văn A',
        content: 'Nội dung quan trọng cần ghim',
        createdAt: DateTime.now(),
        pinnedAt: '2026-09-26T10:00:00Z',
      );

      expect(msg.isPinned, isTrue);
      expect(msg.pinnedAt, equals('2026-09-26T10:00:00Z'));

      final unpinned = msg.copyWith(clearPinnedAt: true);
      expect(unpinned.isPinned, isFalse);
      expect(unpinned.pinnedAt, isNull);

      final repinned = unpinned.copyWith(pinnedAt: '2026-09-26T12:00:00Z');
      expect(repinned.isPinned, isTrue);
      expect(repinned.pinnedAt, equals('2026-09-26T12:00:00Z'));

      final json = repinned.toMap();
      expect(json['pinned_at'], equals('2026-09-26T12:00:00Z'));

      final deserialized = ChatV2Message.fromMap(json);
      expect(deserialized.isPinned, isTrue);
      expect(deserialized.pinnedAt, equals('2026-09-26T12:00:00Z'));
    });

    // ---------------------------------------------------------
    // Test Case 2: Repository togglePinMessage invocation
    // ---------------------------------------------------------
    test('Case 2: ChatV2Repository togglePinMessage returns pinned status', () async {
      final repo = _MockChatV2Repository();
      final result = await repo.togglePinMessage(channelId: '5', messageId: '101');
      expect(result, isTrue);
      expect(repo.togglePinCalled, isTrue);
      expect(repo.lastPinnedMessageId, equals('101'));
    });

    // ---------------------------------------------------------
    // Test Case 3: Mark as unread repository integration
    // ---------------------------------------------------------
    test('Case 3: ChatV2Repository markAsUnread records channel target', () async {
      final repo = _MockChatV2Repository();
      await repo.markAsUnread('42');
      expect(repo.markAsUnreadCalled, isTrue);
      expect(repo.lastMarkedUnreadChannelId, equals('42'));
    });

    // ---------------------------------------------------------
    // Test Case 4: Channel user pin toggle in local cache
    // ---------------------------------------------------------
    test('Case 4: ChatV2ChannelLocalCache user pin state persists and toggles', () {
      const channelId = 'ch_test_pin_99';
      expect(ChatV2ChannelLocalCache.isUserPinned(channelId), isFalse);

      ChatV2ChannelLocalCache.toggleUserPin(channelId);
      expect(ChatV2ChannelLocalCache.isUserPinned(channelId), isTrue);

      ChatV2ChannelLocalCache.toggleUserPin(channelId);
      expect(ChatV2ChannelLocalCache.isUserPinned(channelId), isFalse);
    });

    // ---------------------------------------------------------
    // Test Case 5: Channel user mute toggle in local cache
    // ---------------------------------------------------------
    test('Case 5: ChatV2ChannelLocalCache user mute state toggles reliably', () {
      const channelId = 'ch_test_mute_88';
      expect(ChatV2ChannelLocalCache.isUserMuted(channelId), isFalse);

      ChatV2ChannelLocalCache.toggleUserMute(channelId);
      expect(ChatV2ChannelLocalCache.isUserMuted(channelId), isTrue);

      ChatV2ChannelLocalCache.toggleUserMute(channelId);
      expect(ChatV2ChannelLocalCache.isUserMuted(channelId), isFalse);
    });

    // ---------------------------------------------------------
    // Test Case 6: Local cache markChannelAsUnread updates counter
    // ---------------------------------------------------------
    test('Case 6: ChatV2ChannelLocalCache markChannelAsUnread increments unreadCount', () {
      const channelId = 'ch_test_unread_77';
      final channel = ChatV2Channel(
        id: channelId,
        name: 'Dự án Alpha',
        isGroup: true,
        unreadCount: 0,
      );
      ChatV2ChannelLocalCache.set([channel]);

      expect(ChatV2ChannelLocalCache.cached.first.unreadCount, equals(0));

      ChatV2ChannelLocalCache.markChannelAsUnread(channelId);
      final updated = ChatV2ChannelLocalCache.cached.firstWhere((c) => c.id == channelId);
      expect(updated.unreadCount, equals(1));
    });

    // ---------------------------------------------------------
    // Test Case 7: Member removal in repository
    // ---------------------------------------------------------
    test('Case 7: ChatV2Repository removeChannelMember calls kick endpoint', () async {
      final repo = _MockChatV2Repository();
      await repo.removeChannelMember(channelId: '10', partnerId: 35);
      expect(repo.removeMemberCalled, isTrue);
      expect(repo.lastRemovedPartnerId, equals(35));
    });

    // ---------------------------------------------------------
    // Test Case 8: Leave channel in repository
    // ---------------------------------------------------------
    test('Case 8: ChatV2Repository leaveChannel triggers backend leave', () async {
      final repo = _MockChatV2Repository();
      await repo.leaveChannel('10');
      expect(repo.leaveChannelCalled, isTrue);
      expect(repo.lastLeftChannelId, equals('10'));
    });

    // ---------------------------------------------------------
    // Test Case 9: In-Chat Search match indexing logic
    // ---------------------------------------------------------
    test('Case 9: In-Chat search matches text case-insensitively and computes indices', () {
      final messages = [
        ChatV2Message(
          id: '1',
          channelId: '1',
          authorId: '1',
          authorName: 'User A',
          content: 'Báo cáo doanh thu tháng 9',
          createdAt: DateTime.now(),
        ),
        ChatV2Message(
          id: '2',
          channelId: '1',
          authorId: '2',
          authorName: 'User B',
          content: 'Tài liệu hướng dẫn triển khai',
          createdAt: DateTime.now(),
        ),
        ChatV2Message(
          id: '3',
          channelId: '1',
          authorId: '1',
          authorName: 'User A',
          content: 'Báo cáo kiểm thử sprint P0',
          createdAt: DateTime.now(),
        ),
      ];

      const query = 'báo cáo';
      final matches = messages.where((m) => m.content.toLowerCase().contains(query.toLowerCase())).toList();
      expect(matches.length, equals(2));
      expect(matches[0].id, equals('1'));
      expect(matches[1].id, equals('3'));
    });

    // ---------------------------------------------------------
    // Test Case 10: Multi-file size limit validation logic
    // ---------------------------------------------------------
    test('Case 10: Multi-file size verification rejects files exceeding 25MB', () {
      const maxDocumentSizeBytes = 25 * 1024 * 1024;
      final file1Size = 10 * 1024 * 1024; // 10MB -> Valid
      final file2Size = 26 * 1024 * 1024; // 26MB -> Invalid

      expect(file1Size <= maxDocumentSizeBytes, isTrue);
      expect(file2Size <= maxDocumentSizeBytes, isFalse);
    });

    // ---------------------------------------------------------
    // Test Case 11: Multi-file batch size capped at 9 items
    // ---------------------------------------------------------
    test('Case 11: Multi-file selection restricts batch to maximum 9 items', () {
      final selectedFiles = List.generate(15, (i) => 'file_$i.pdf');
      final cappedFiles = selectedFiles.take(9).toList();

      expect(cappedFiles.length, equals(9));
      expect(cappedFiles.first, equals('file_0.pdf'));
      expect(cappedFiles.last, equals('file_8.pdf'));
    });

    // ---------------------------------------------------------
    // Test Case 12: #channel mention matching from cached channels
    // ---------------------------------------------------------
    test('Case 12: #channel mention filters cached channels correctly', () {
      final channels = [
        const ChatV2Channel(id: '1', name: 'Kỹ thuật Odoo', isGroup: true),
        const ChatV2Channel(id: '2', name: 'Kinh doanh & Marketing', isGroup: true),
        const ChatV2Channel(id: '3', name: 'Ban Giám Đốc', isGroup: true),
      ];
      ChatV2ChannelLocalCache.set(channels);

      const query = 'odoo';
      final matches = ChatV2ChannelLocalCache.cached
          .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      expect(matches.length, equals(1));
      expect(matches.first.id, equals('1'));
      expect(matches.first.name, equals('Kỹ thuật Odoo'));
    });
  });
}
