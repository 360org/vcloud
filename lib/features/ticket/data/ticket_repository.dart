import 'dart:async';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/ticket.dart';

class TicketRepository {
  TicketRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Stream<List<Ticket>> watchAssigned() {
    final ctl = StreamController<List<Ticket>>();

    Future<void> refresh() async {
      try {
        final res = await _client.get('/api/v1/mobile/ticket/list');
        final list = (res as List)
            .cast<Map<String, dynamic>>()
            .map(_ticketFromOdoo)
            .map(Ticket.fromMap)
            .toList();
        if (!ctl.isClosed) ctl.add(list);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Reload failed: $e'));
      }
    }

    ctl.onListen = refresh;
    return ctl.stream;
  }

  Future<Ticket> create({
    required String title,
    required String? description,
    TicketPriority priority = TicketPriority.p3,
    String? category,
  }) async {
    final teamId = int.tryParse(category ?? '') ?? 1;
    final res = await _client.post(
      '/api/v1/mobile/ticket/create',
      body: <String, dynamic>{
        'team_id': teamId,
        'name': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'priority': _priorityToOdoo(priority),
      },
    );
    return one((res['id'] as num).toInt().toString());
  }

  Future<Ticket> updateStatus(String id, TicketStatus status) async {
    await _client.put(
      '/api/v1/helpdesk.ticket/$id',
      body: <String, dynamic>{
        'values': <String, dynamic>{
          'kanban_state': status == TicketStatus.done ? 'done' : 'normal',
        },
      },
    );
    return one(id);
  }

  Future<Ticket> updatePriority(String id, TicketPriority priority) async {
    await _client.put(
      '/api/v1/helpdesk.ticket/$id',
      body: <String, dynamic>{
        'values': <String, dynamic>{'priority': _priorityToOdoo(priority)},
      },
    );
    return one(id);
  }

  Future<Ticket> updateCategory(String id, String? category) async {
    await _client.put(
      '/api/v1/helpdesk.ticket/$id',
      body: <String, dynamic>{
        'values': <String, dynamic>{
          if (category != null) 'team_id': int.tryParse(category),
        },
      },
    );
    return one(id);
  }

  Future<Ticket> one(String id) async {
    final res = await _client.get('/api/v1/mobile/ticket/$id');
    return Ticket.fromMap(
      _ticketFromOdoo(Map<String, dynamic>.from(res as Map)),
    );
  }

  Future<void> delete(String id) async {
    await _client.delete('/api/v1/helpdesk.ticket/$id');
  }

  Map<String, dynamic> _ticketFromOdoo(Map<String, dynamic> map) {
    final created =
        map['create_date'] as String? ?? DateTime.now().toIso8601String();
    final closeDate = map['close_date'] as String?;
    return <String, dynamic>{
      'id': map['id'].toString(),
      'title': (map['name'] ?? map['ticket_ref'] ?? 'Ticket').toString(),
      'description': map['description'] as String?,
      'status': closeDate == null
          ? TicketStatus.doing.dbValue
          : TicketStatus.done.dbValue,
      'created_by': _many2OneId(map['partner_id']) ?? '',
      'assigned_to': _many2OneId(map['user_id']) ?? '',
      'created_at': created,
      'updated_at': closeDate ?? map['assign_date'] as String? ?? created,
      'priority': _priorityFromOdoo(map['priority'] as String?),
      'category': map['team_name'] as String?,
    };
  }

  String _priorityToOdoo(TicketPriority priority) => switch (priority) {
    TicketPriority.p1 => '3',
    TicketPriority.p2 => '2',
    TicketPriority.p3 => '1',
    TicketPriority.p4 => '0',
  };

  String _priorityFromOdoo(String? priority) => switch (priority) {
    '3' => TicketPriority.p1.dbValue,
    '2' => TicketPriority.p2.dbValue,
    '1' => TicketPriority.p3.dbValue,
    '0' => TicketPriority.p4.dbValue,
    _ => TicketPriority.p3.dbValue,
  };

  String? _many2OneId(Object? value) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is int) return value.toString();
    return null;
  }
}
