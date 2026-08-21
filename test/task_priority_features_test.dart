import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  group('Task Priority Features & Hardening Tests (AIaC 2026)', () {
    test('Task #16443 & #16445: Task correctly parses and holds remaining_hours', () {
      final now = DateTime.now();
      final map = {
        'id': '16445',
        'title': 'Test Timesheet Task',
        'allocated_hours': 4.0,
        'spent_hours': 1.5,
        'remaining_hours': 2.5,
        'stage_name': 'Backlog',
      };

      final task = Task(
        id: map['id'] as String,
        userId: '103',
        title: map['title'] as String,
        category: TimesheetCategory.other,
        dueDate: now,
        createdAt: now,
        updatedAt: now,
        allocatedHours: (map['allocated_hours'] as num).toDouble(),
        spentHours: (map['spent_hours'] as num).toDouble(),
        remainingHours: (map['remaining_hours'] as num).toDouble(),
        stageName: map['stage_name'] as String,
      );

      expect(task.allocatedHours, 4.0);
      expect(task.spentHours, 1.5);
      expect(task.remainingHours, 2.5);
    });

    test('Task #16442: OdooApiClient.authenticatedUrl attaches JWT token correctly', () {
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
      );

      final authUrl = client.authenticatedUrl(
        '/web/image/12345/document.pdf',
        accessToken: 'mock_jwt_token_123',
      );
      expect(authUrl, contains('https://vuahethong.net/web/image/12345/document.pdf'));
      expect(authUrl, contains('access_token=mock_jwt_token_123'));
    });

    test('Task #16444 & #16435: ChatV2Channel distinguishes internal direct vs group vs channel', () {
      const directChannel = ChatV2Channel(
        id: '1',
        name: 'Trần Văn A, Ma Nguyễn Nhật Tân',
        channelType: 'chat',
        members: [
          ChatV2Member(id: '1', name: 'Trần Văn A'),
          ChatV2Member(id: '2', name: 'Ma Nguyễn Nhật Tân'),
        ],
      );

      const groupChannel = ChatV2Channel(
        id: '2',
        name: 'Nhóm Phát Triển Mobile',
        channelType: 'group',
        members: [
          ChatV2Member(id: '1', name: 'Trần Văn A'),
          ChatV2Member(id: '2', name: 'Ma Nguyễn Nhật Tân'),
          ChatV2Member(id: '3', name: 'Nguyễn Văn C'),
        ],
      );

      const channelPub = ChatV2Channel(
        id: '3',
        name: 'Thông báo toàn công ty',
        channelType: 'channel',
        members: [],
      );

      expect(directChannel.isInternalDirect('Ma Nguyễn Nhật Tân'), isTrue);
      expect(directChannel.isGroupChat('Ma Nguyễn Nhật Tân'), isFalse);
      expect(directChannel.isChannel, isFalse);

      expect(groupChannel.isGroupChat('Ma Nguyễn Nhật Tân'), isTrue);
      expect(groupChannel.isInternalDirect('Ma Nguyễn Nhật Tân'), isFalse);

      expect(channelPub.isChannel, isTrue);
    });
  });
}
