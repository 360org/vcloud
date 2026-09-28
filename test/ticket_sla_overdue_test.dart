import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/models/ticket.dart';

void main() {
  group('Ticket.isOverdue SLA Tests (BUG-012)', () {
    final now = DateTime.now();
    final pastDate = now.subtract(const Duration(days: 3));
    final futureDate = now.add(const Duration(days: 3));

    test('Ticket without deadline is NEVER overdue even if createdAt was days ago', () {
      final ticket = Ticket(
        id: '1',
        title: 'Ticket without deadline',
        description: 'Test',
        status: TicketStatus.doing,
        createdBy: 'user',
        assignedTo: 'user',
        createdAt: pastDate,
        updatedAt: pastDate,
        deadline: null,
      );

      expect(ticket.isOverdue, isFalse,
          reason: 'Tickets without an explicit deadline must not trigger false overdue alarms');
    });

    test('Ticket with past deadline is overdue when not done', () {
      final ticket = Ticket(
        id: '2',
        title: 'Overdue Ticket',
        description: 'Test',
        status: TicketStatus.doing,
        createdBy: 'user',
        assignedTo: 'user',
        createdAt: pastDate,
        updatedAt: pastDate,
        deadline: pastDate,
      );

      expect(ticket.isOverdue, isTrue);
    });

    test('Ticket with future deadline is not overdue', () {
      final ticket = Ticket(
        id: '3',
        title: 'On-track Ticket',
        description: 'Test',
        status: TicketStatus.doing,
        createdBy: 'user',
        assignedTo: 'user',
        createdAt: pastDate,
        updatedAt: pastDate,
        deadline: futureDate,
      );

      expect(ticket.isOverdue, isFalse);
    });

    test('Completed ticket is never overdue even with past deadline', () {
      final ticket = Ticket(
        id: '4',
        title: 'Completed Ticket',
        description: 'Test',
        status: TicketStatus.done,
        createdBy: 'user',
        assignedTo: 'user',
        createdAt: pastDate,
        updatedAt: pastDate,
        deadline: pastDate,
      );

      expect(ticket.isOverdue, isFalse);
    });
  });
}
