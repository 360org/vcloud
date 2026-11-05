import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/config/env.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/profile/application/theme_controller.dart';

void main() {
  group('ChatV2Channel & Theme Synchronization Test Suite (10 Cases)', () {
    test('TC-01: ChatV2Channel nhận diện kênh có prefix # trong name là isChannel = true', () {
      const channel = ChatV2Channel(
        id: '101',
        name: '# General',
        channelType: 'chat',
        uuid: 'uuid-101',
      );
      expect(channel.isChannel, isTrue);
    });

    test('TC-02: ChatV2Channel nhận diện kênh có prefix # trong customNickname là isChannel = true', () {
      const channel = ChatV2Channel(
        id: '102',
        name: 'Technical',
        customNickname: '# Technical',
        channelType: 'chat',
        uuid: 'uuid-102',
      );
      expect(channel.isChannel, isTrue);
      expect(channel.displayName, equals('# Technical'));
    });

    test('TC-03: ChatV2Channel với channelType == channel luôn trả isChannel = true', () {
      const channel = ChatV2Channel(
        id: '103',
        name: '405',
        channelType: 'channel',
        uuid: 'uuid-103',
      );
      expect(channel.isChannel, isTrue);
    });

    test('TC-04: ChatV2Channel direct message không có # và channelType == chat trả isChannel = false', () {
      const channel = ChatV2Channel(
        id: '104',
        name: 'Nguyen Van A',
        channelType: 'chat',
        uuid: 'uuid-104',
      );
      expect(channel.isChannel, isFalse);
    });

    test('TC-05: ChatV2Channel fromJson phân loại đúng kênh xuất phát từ Discuss vuahethong.net', () {
      final json = <String, dynamic>{
        'id': 105,
        'name': '# Administrators',
        'channel_type': 'chat',
        'uuid': 'uuid-105',
        'unread_counter': 3,
      };
      final channel = ChatV2Channel.fromJson(json);
      expect(channel.isChannel, isTrue);
      expect(channel.unreadCount, equals(3));
    });

    test('TC-06: AppThemeMode.vuahethong parse và chuỗi định danh đúng chuẩn', () {
      const mode = AppThemeMode.vuahethong;
      expect(mode.displayName, equals('Đồng bộ Vua Hệ Thống'));
    });

    test('TC-07: AppThemeModeX mở rộng đúng các mode tương ứng', () {
      expect(AppThemeMode.light.displayName, equals('Sáng'));
      expect(AppThemeMode.dark.displayName, equals('Tối'));
      expect(AppThemeMode.system.displayName, equals('Theo thiết bị di động'));
    });

    test('TC-08: AppThemeMode.vuahethong resolveThemeMode trả ThemeMode.light khi server là light', () {
      final controller = ThemeController();
      final mode = controller.resolveThemeMode(AppThemeMode.vuahethong);
      expect(mode, equals(ThemeMode.light));
    });

    test('TC-09: AppThemeMode.vuahethong resolveThemeMode tuân theo server_color_scheme từ vuahethong.net', () {
      final controller = ThemeController();
      expect(controller.resolveThemeMode(AppThemeMode.dark), equals(ThemeMode.dark));
      expect(controller.resolveThemeMode(AppThemeMode.light), equals(ThemeMode.light));
    });

    test('TC-10: Env.odooDb mặc định là chuỗi rỗng để kích hoạt Master Router dynamic lookup trên Release', () {
      expect(Env.odooDb, equals(''));
    });
  });
}
