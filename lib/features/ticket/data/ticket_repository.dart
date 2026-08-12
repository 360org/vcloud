import 'dart:async';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/api/mobile_attachment_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/html_text.dart';
import '../../../shared/models/ticket.dart';

import '../../../shared/models/ticket_activity.dart';

class TicketRepository {
  TicketRepository({
    OdooApiClient? client,
    MobileAttachmentRepository? attachmentRepository,
  }) : _client = client ?? odooApiClient,
       _attachmentRepository =
           attachmentRepository ??
           MobileAttachmentRepository(client: client ?? odooApiClient);

  static const _ticketBasePath = '/api/v1/mobile/ticket';
  static final Map<String, String> _descriptionCache = <String, String>{};

  final OdooApiClient _client;
  final MobileAttachmentRepository _attachmentRepository;

  Stream<List<Ticket>> watchAssigned({TicketFilter? filter}) {
    final ctl = StreamController<List<Ticket>>();

    Future<void> refresh() async {
      try {
        final queryParams = <String, String>{};
        if (filter?.priority != null) {
          queryParams['priority'] = _priorityToOdoo(filter!.priority!);
        }
        if (filter?.teamId != null) {
          queryParams['team_id'] = filter!.teamId.toString();
        }
        final queryString = queryParams.isNotEmpty
            ? '?${Uri(queryParameters: queryParams).query}'
            : '';

        final res = await _client.get('$_ticketBasePath/list$queryString');
        final rawList = (res as List).cast<Map<String, dynamic>>();

        await Future.wait(
          rawList.map((map) async {
            final id = map['id'].toString();
            final desc = _cleanOptionalText(map['description']);
            if (desc != null && desc.isNotEmpty) {
              _descriptionCache[id] = desc;
            } else if (!_descriptionCache.containsKey(id)) {
              try {
                final detail = await _client.get('$_ticketBasePath/$id');
                if (detail is Map) {
                  final cleaned = _cleanOptionalText(detail['description']);
                  if (cleaned != null && cleaned.isNotEmpty) {
                    _descriptionCache[id] = cleaned;
                  }
                }
              } catch (_) {}
            }
          }),
        );

        final list = rawList
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

  Future<List<TicketTeamOption>> teams() async {
    final res = await _client.get('$_ticketBasePath/teams');
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(TicketTeamOption.fromMap)
        .where((team) => team.name.isNotEmpty)
        .toList();
  }

  Future<Ticket> create({
    required String title,
    required String? description,
    TicketPriority priority = TicketPriority.p3,
    String? category,
    List<int> tagIds = const <int>[],
    List<MobileAttachmentUpload> attachments = const <MobileAttachmentUpload>[],
  }) async {
    final teamId = int.tryParse(category ?? '') ?? 1;
    final res = await _client.post(
      '$_ticketBasePath/create',
      body: <String, dynamic>{
        'team_id': teamId,
        'name': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'priority': _priorityToOdoo(priority),
        if (tagIds.isNotEmpty) 'tag_ids': tagIds,
      },
    );
    final ticketId = (res['id'] as num).toInt();
    for (final attachment in attachments) {
      await _attachmentRepository.upload(
        MobileAttachmentUpload(
          filename: attachment.filename,
          bytes: attachment.bytes,
          mimetype: attachment.mimetype,
          resModel: 'helpdesk.ticket',
          resId: ticketId,
        ),
      );
    }
    return one(ticketId.toString());
  }

  Future<void> sendContact(String ticketId, int partnerId) async {
    await _client.post(
      '$_ticketBasePath/$ticketId/contact',
      body: <String, dynamic>{'partner_id': partnerId},
    );
  }

  Future<Ticket> updateStatus(String id, TicketStatus status) async {
    final odooStatus = status == TicketStatus.done ? 'done' : 'in_progress';
    try {
      await _client.post(
        '/api/v1/mobile/ticket/$id/workflow',
        body: <String, dynamic>{'status': odooStatus},
      );
      return await one(id);
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Lỗi khi cập nhật trạng thái Ticket: $e');
    }
  }

  Future<Ticket> updatePriority(String id, TicketPriority priority) async {
    throw Failure('360 Support API chưa hỗ trợ cập nhật ưu tiên ticket.');
  }

  Future<Ticket> updateCategory(String id, String? category) async {
    throw Failure('360 Support API chưa hỗ trợ đổi đội xử lý ticket.');
  }

  Future<Ticket> one(String id) async {
    final res = await _client.get('$_ticketBasePath/$id');
    return Ticket.fromMap(
      _ticketFromOdoo(Map<String, dynamic>.from(res as Map)),
    );
  }

  Future<void> delete(String id) async {
    throw Failure('360 Support API chưa hỗ trợ xoá ticket.');
  }

  Map<String, dynamic> _ticketFromOdoo(Map<String, dynamic> map) {
    final created =
        map['create_date'] as String? ?? DateTime.now().toIso8601String();
    
    final stageRaw = map['stage_id'] ?? map['stage_name'];
    final stageName = stageRaw is List && stageRaw.length > 1
        ? stageRaw[1].toString().toLowerCase()
        : (stageRaw?.toString().toLowerCase() ?? '');
    
    final closeDate = map['close_date'] ?? map['date_done'];
    final hasCloseDate = closeDate != null && closeDate != false && closeDate != 'false';
    final state = map['state']?.toString();
    
    final isDone = hasCloseDate ||
        state == '1_done' ||
        state == '1_canceled' ||
        stageName.contains('done') ||
        stageName.contains('hoàn thành') ||
        stageName.contains('đã đóng') ||
        stageName.contains('đã xong');

    final updatedAtStr = hasCloseDate ? closeDate.toString() : created;

    final assignedTo = _many2OneId(map['user_id']) ?? '';
    final hasAssignee = assignedTo.isNotEmpty;
    final idStr = map['id'].toString();
    var desc = _cleanOptionalText(map['description']);
    if ((desc == null || desc.isEmpty) && _descriptionCache.containsKey(idStr)) {
      desc = _descriptionCache[idStr];
    }

    return <String, dynamic>{
      'id': idStr,
      'title': _ticketTitle(map),
      'description': desc,
      'status': isDone
          ? TicketStatus.done.dbValue
          : (hasAssignee ? TicketStatus.doing.dbValue : TicketStatus.todo.dbValue),
      'created_by': _many2OneId(map['partner_id']) ?? '',
      'assigned_to': assignedTo,
      'created_at': created,
      'updated_at': updatedAtStr,
      'priority': _priorityFromOdoo(map['priority'] as String?),
      'category': map['team_name'] as String?,
      'tag_labels': _tagLabels(map['tags']),
      'attachments': map['attachments'],
    };
  }

  Future<List<TicketActivity>> activities(
    String ticketId, {
    bool includeDone = true,
  }) async {
    final doneFlag = includeDone ? '1' : '0';
    final res = await _client.get(
      '$_ticketBasePath/$ticketId/activities?done=$doneFlag',
    );
    if (res is! List) return const <TicketActivity>[];
    return res
        .whereType<Map>()
        .map((item) => TicketActivity.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _ticketTitle(Map<String, dynamic> map) {
    final name = cleanHtmlText(map['name']);
    if (name.isNotEmpty) return name;

    final ticketRef = cleanHtmlText(map['ticket_ref']);
    return ticketRef.isNotEmpty ? ticketRef : 'Ticket';
  }

  String? _cleanOptionalText(Object? value) {
    final text = cleanHtmlText(value);
    return text.isEmpty ? null : text;
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

  List<String> _tagLabels(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map((tag) {
          if (tag is Map) return cleanHtmlText(tag['name']);
          return cleanHtmlText(tag);
        })
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
}
