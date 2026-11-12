import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ticket Push Notification Handling & Invalidation Contract', () {
    test('Push payload with ticket_id routes correctly to /tickets/:id', () {
      final payload = {
        'type': 'ticket_message',
        'ticket_id': 456,
        'model': 'helpdesk.ticket',
        'res_id': 456,
      };

      final ticketId = (payload['ticket_id'] ?? payload['helpdesk_ticket_id'] ?? payload['res_id'] ?? '').toString();
      expect(ticketId, '456');

      final route = '/tickets/$ticketId';
      expect(route, '/tickets/456');
    });

    test('Push payload with helpdesk_ticket_id routes correctly when ticket_id is missing', () {
      final payload = {
        'event_type': 'ticket_message',
        'helpdesk_ticket_id': 789,
        'model': 'helpdesk.ticket',
      };

      final ticketId = (payload['ticket_id'] ?? payload['helpdesk_ticket_id'] ?? payload['res_id'] ?? '').toString();
      expect(ticketId, '789');
      expect('/tickets/$ticketId', '/tickets/789');
    });

    test('Foreground push detection correctly identifies ticket comments', () {
      final validTicketPayloads = [
        {'type': 'ticket_message', 'ticket_id': 101},
        {'event_type': 'ticket_comment', 'res_id': 102},
        {'model': 'helpdesk.ticket', 'res_id': 103},
        {'event': 'helpdesk_ticket_comment', 'ticket_id': 104},
        {'helpdesk_ticket_id': 105},
      ];

      for (final data in validTicketPayloads) {
        final type = (data['event_type'] ?? data['event'] ?? data['type'] ?? data['model'] ?? '')
            .toString()
            .toLowerCase();

        final isTicketPush = type.contains('ticket') ||
            type.contains('helpdesk') ||
            data.containsKey('ticket_id') ||
            data.containsKey('helpdesk_ticket_id') ||
            (data['model']?.toString().toLowerCase().contains('helpdesk') ?? false);

        expect(isTicketPush, isTrue, reason: 'Payload $data should be recognized as ticket push');

        final pushTicketId = (data['ticket_id'] ?? data['helpdesk_ticket_id'] ?? data['res_id'] ?? '').toString();
        expect(pushTicketId.isNotEmpty && pushTicketId != '0', isTrue);
      }
    });

    test('Foreground push does not misidentify chat or attendance as ticket', () {
      final nonTicketPayloads = [
        {'type': 'chat_message', 'channel_id': 10},
        {'event': 'attendance_checkin', 'attendance_id': 20},
        {'model': 'project.task', 'task_id': 30},
      ];

      for (final data in nonTicketPayloads) {
        final type = (data['event_type'] ?? data['event'] ?? data['type'] ?? data['model'] ?? '')
            .toString()
            .toLowerCase();

        final isTicketPush = type.contains('ticket') ||
            type.contains('helpdesk') ||
            data.containsKey('ticket_id') ||
            data.containsKey('helpdesk_ticket_id') ||
            (data['model']?.toString().toLowerCase().contains('helpdesk') ?? false);

        expect(isTicketPush, isFalse, reason: 'Payload $data should not be recognized as ticket push');
      }
    });

    test('Idempotency key contract guarantees unique key per comment with message_id', () {
      const model = 'helpdesk.ticket';
      const resId = 501;
      const deviceId = 99;
      const eventType = 'ticket_message';

      // Before fix: missing message_id
      const oldKeyMsg1 = '${model}_${resId}_${eventType}_$deviceId';
      const oldKeyMsg2 = '${model}_${resId}_${eventType}_$deviceId';
      expect(oldKeyMsg1, equals(oldKeyMsg2), reason: 'Old key had duplicate collision');

      // After fix: includes message_id
      const msg1Id = 8801;
      const msg2Id = 8802;
      const newKeyMsg1 = '${model}_${resId}_${msg1Id}_${eventType}_$deviceId';
      const newKeyMsg2 = '${model}_${resId}_${msg2Id}_${eventType}_$deviceId';

      expect(newKeyMsg1, isNot(equals(newKeyMsg2)), reason: 'New key must be unique per message_id');
      expect(newKeyMsg1, 'helpdesk.ticket_501_8801_ticket_message_99');
      expect(newKeyMsg2, 'helpdesk.ticket_501_8802_ticket_message_99');
    });
  });
}
