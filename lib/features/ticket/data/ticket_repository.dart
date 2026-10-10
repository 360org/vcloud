import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

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
  static List<Ticket> _cachedTickets = const <Ticket>[];

  /// Xóa sạch toàn bộ bộ nhớ đệm Ticket trong RAM (In-Memory Cache Wipe).
  /// Ngăn chặn rò rỉ Ticket cũ khi logout hoặc chuyển đổi user (Protocol V2.1).
  static void clearCache() {
    _cachedTickets = const <Ticket>[];
    _descriptionCache.clear();
  }

  /// Nối tiếp vé mới vào bộ nhớ đệm RAM (Infinite Scroll).
  static void appendCachedTickets(List<Ticket> newTickets) {
    final existingIds = _cachedTickets.map((t) => t.id).toSet();
    final toAdd = newTickets.where((t) => !existingIds.contains(t.id)).toList();
    if (toAdd.isNotEmpty) {
      _cachedTickets = [..._cachedTickets, ...toAdd];
    }
  }

  @visibleForTesting
  static List<Ticket> get cachedTicketsForTesting => _cachedTickets;

  @visibleForTesting
  static void setCachedTicketsForTesting(List<Ticket> tickets) {
    _cachedTickets = tickets;
  }

  final OdooApiClient _client;
  final MobileAttachmentRepository _attachmentRepository;

  Future<List<Ticket>> fetchTickets({
    TicketFilter? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{};
    final f = filter;
    if (f != null) {
      if (f.priority != null) {
        queryParams['priority'] = _priorityToOdoo(f.priority!);
      }
      if (f.teamId != null) {
        queryParams['team_id'] = f.teamId.toString();
      }
      if (f.search != null && f.search!.trim().isNotEmpty) {
        queryParams['search'] = f.search!.trim();
      }
      if (f.limit != null && f.limit! > 0) {
        queryParams['limit'] = f.limit!.toString();
      } else if (offset > 0) {
        queryParams['limit'] = limit.toString();
      }
      if (f.offset != null && f.offset! > 0) {
        queryParams['offset'] = f.offset!.toString();
      } else if (offset > 0) {
        queryParams['offset'] = offset.toString();
      }
    } else if (offset > 0) {
      queryParams['offset'] = offset.toString();
      queryParams['limit'] = limit.toString();
    }

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    final res = await _client.get('$_ticketBasePath/list$queryString');
    final rawList = (res as List).cast<Map<String, dynamic>>();

    for (final map in rawList) {
      final id = map['id'].toString();
      final desc = _cleanOptionalText(map['description']);
      if (desc != null && desc.isNotEmpty) {
        _descriptionCache[id] = desc;
      }
    }

    return rawList
        .map(_ticketFromOdoo)
        .map(Ticket.fromMap)
        .toList();
  }

  Stream<List<Ticket>> watchAssigned({TicketFilter? filter}) {
    final ctl = StreamController<List<Ticket>>.broadcast();

    Future<void> refresh() async {
      // 1. SWR Cache: Phát ngay dữ liệu có sẵn trong RAM để render 0ms
      if (_cachedTickets.isNotEmpty && !ctl.isClosed) {
        ctl.add(_cachedTickets);
      }

      try {
        final list = await fetchTickets(
          filter: filter,
          limit: filter?.limit ?? 20,
          offset: filter?.offset ?? 0,
        );
        _cachedTickets = list;
        if (!ctl.isClosed) ctl.add(list);
      } catch (e) {
        debugPrint('TicketRepository watchAssigned error: $e');
        if (!ctl.isClosed && _cachedTickets.isNotEmpty) {
          ctl.add(_cachedTickets);
        } else if (!ctl.isClosed) {
          ctl.add(const <Ticket>[]);
        }
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

  Future<List<TicketTagOption>> tags() async {
    try {
      final res = await _client.get('$_ticketBasePath/tags');
      if (res is List) {
        return res
            .cast<Map<String, dynamic>>()
            .map(TicketTagOption.fromMap)
            .where((tag) => tag.name.isNotEmpty)
            .toList();
      }
      return const <TicketTagOption>[];
    } catch (_) {
      return const <TicketTagOption>[];
    }
  }

  Future<Ticket> create({
    required String title,
    required String? description,
    TicketPriority priority = TicketPriority.p3,
    String? category,
    List<int> tagIds = const <int>[],
    List<MobileAttachmentUpload> attachments = const <MobileAttachmentUpload>[],
    int? partnerId,
    DateTime? dateDeadline,
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
        'partner_id': ?partnerId,
        'date_deadline': ?dateDeadline?.toIso8601String(),
      },
    );
    final ticketId = (res['id'] as num).toInt();
    final resModel = res['res_model']?.toString() ?? res['model']?.toString() ?? 'helpdesk.ticket';
    for (final attachment in attachments) {
      await _attachmentRepository.upload(
        MobileAttachmentUpload(
          filename: attachment.filename,
          bytes: attachment.bytes,
          mimetype: attachment.mimetype,
          resModel: resModel,
          resId: ticketId,
        ),
      );
    }
    return one(ticketId.toString());
  }

  Future<void> sendContact(String ticketId, int partnerId) async {
    // ponytail: Thay route ảo bằng message chatter chuẩn Odoo
    try {
      await _client.post(
        '$_ticketBasePath/$ticketId/message',
        body: <String, dynamic>{
          'body': 'Đã chia sẻ thông tin liên hệ (Partner ID: $partnerId) vào ticket.',
        },
      );
    } catch (_) {}
  }

  Future<Ticket> update(
    String id, {
    String? title,
    String? description,
    TicketPriority? priority,
    String? category,
    int? assigneeId,
  }) async {
    try {
      await _client.post(
        '$_ticketBasePath/$id/update',
        body: <String, dynamic>{
          if (title != null && title.isNotEmpty) 'name': title,
          'description': ?description,
          if (priority != null) 'priority': _priorityToOdoo(priority),
          if (category != null) 'team_id': int.tryParse(category),
          'user_id': ?assigneeId,
        },
      );
      final updatedTicket = await one(id);
      _cachedTickets = [
        for (final t in _cachedTickets)
          if (t.id == id) updatedTicket else t,
      ];
      return updatedTicket;
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Lỗi khi cập nhật Ticket: $e');
    }
  }

  Future<Ticket> updateStatus(String id, TicketStatus status) async {
    final odooStatus = status == TicketStatus.done ? 'done' : 'in_progress';
    try {
      await _client.post(
        '/api/v1/mobile/ticket/$id/workflow',
        body: <String, dynamic>{'status': odooStatus},
      );
      final updatedTicket = await one(id);
      _cachedTickets = [
        for (final t in _cachedTickets)
          if (t.id == id) updatedTicket else t,
      ];
      return updatedTicket;
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Lỗi khi cập nhật trạng thái Ticket: $e');
    }
  }

  Future<Ticket> updatePriority(String id, TicketPriority priority) async {
    return update(id, priority: priority);
  }

  Future<Ticket> updateCategory(String id, String? category) async {
    return update(id, category: category);
  }

  Future<Ticket> assignUser(String id, int userId) async {
    return update(id, assigneeId: userId);
  }

  Future<List<Map<String, dynamic>>> assignees() async {
    try {
      final res = await _client.get('$_ticketBasePath/assignees');
      if (res is List) {
        return res.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> partners({String? query}) async {
    try {
      final q = query != null && query.trim().isNotEmpty
          ? '?q=${Uri.encodeComponent(query.trim())}'
          : '';
      final res = await _client.get('/api/v1/mobile/contacts$q');
      if (res is List) {
        return res
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((p) => (p['name']?.toString().trim().isNotEmpty ?? false))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
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
    final updated =
        map['write_date'] as String? ?? created;
    
    final stageRaw = map['stage_id'] ?? map['stage_name'];
    final stageName = stageRaw is List && stageRaw.length > 1
        ? stageRaw[1].toString().toLowerCase()
        : (stageRaw?.toString().toLowerCase() ?? '');
    
    final closeDate = map['close_date'] ?? map['date_done'];
    final hasCloseDate = closeDate != null && closeDate != false && closeDate != 'false' && closeDate != '';
    final state = map['state']?.toString();
    final statusStr = map['status']?.toString();
    
    final isDone = hasCloseDate ||
        state == '1_done' ||
        state == '1_canceled' ||
        statusStr == 'done' ||
        stageName.contains('done') ||
        stageName.contains('hoàn thành') ||
        stageName.contains('đã đóng') ||
        stageName.contains('đã xong') ||
        stageName.contains('solved');

    final updatedAtStr = hasCloseDate ? closeDate.toString() : updated;

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
      'partner_name': _many2OneName(map['partner_id']) ?? map['partner_name'] as String?,
      'user_name': _many2OneName(map['user_id']) ?? map['user_name'] as String?,
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

  String? _many2OneName(Object? value) {
    if (value is List && value.length > 1) {
      final name = value[1]?.toString().trim();
      return (name != null && name.isNotEmpty) ? name : null;
    }
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
