import 'dart:convert';
import 'dart:typed_data';

import '../error/failure.dart';
import 'odoo_api_client.dart';

class MobileAttachmentUpload {
  const MobileAttachmentUpload({
    required this.filename,
    required this.bytes,
    this.resModel,
    this.resId,
    this.mimetype,
  });

  final String filename;
  final Uint8List bytes;
  final String? resModel;
  final int? resId;
  final String? mimetype;
}

class MobileAttachment {
  const MobileAttachment({
    required this.id,
    required this.attachmentId,
    required this.name,
    this.mimetype,
    this.fileSize,
    this.url,
    this.downloadUrl,
    this.accessToken,
  });

  factory MobileAttachment.fromMap(Map<String, dynamic> map) {
    final id = _intOrNull(map['id'] ?? map['attachment_id']);
    final attachmentId = _intOrNull(map['attachment_id'] ?? map['id']);
    if (id == null || attachmentId == null) {
      throw Failure('Phản hồi attachment thiếu id.');
    }
    return MobileAttachment(
      id: id,
      attachmentId: attachmentId,
      name: (map['name'] ?? map['filename'] ?? '').toString(),
      mimetype: _stringOrNull(map['mimetype']),
      fileSize: _intOrNull(map['file_size']),
      url: _stringOrNull(map['url']),
      downloadUrl: _stringOrNull(map['download_url']),
      accessToken: _stringOrNull(map['access_token']),
    );
  }

  final int id;
  final int attachmentId;
  final String name;
  final String? mimetype;
  final int? fileSize;
  final String? url;
  final String? downloadUrl;
  final String? accessToken;
}

class MobileAttachmentRepository {
  MobileAttachmentRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Future<MobileAttachment> upload(MobileAttachmentUpload file) async {
    final b64 = base64Encode(file.bytes).replaceAll('\r', '').replaceAll('\n', '').trim();
    final res = await _client.post(
      '/api/v1/mobile/attachments/upload',
      body: <String, dynamic>{
        'filename': file.filename,
        'name': file.filename,
        'base64': b64,
        'datas': b64,
        if (file.mimetype != null) 'mimetype': file.mimetype,
        if (file.resModel != null) 'res_model': file.resModel,
        if (file.resId != null) 'res_id': file.resId,
      },
    );
    return MobileAttachment.fromMap(_responseMap(res));
  }

  Future<MobileAttachment> one(int id) async {
    final res = await _client.get('/api/v1/mobile/attachments/$id');
    return MobileAttachment.fromMap(_responseMap(res));
  }

  /// Downloads the raw bytes of an attachment via the dedicated Bearer-
  /// authenticated download endpoint. Falls back to Odoo standard
  /// /web/content/ route if the custom endpoint is not available.
  Future<Uint8List> fetchBytes(int attachmentId, {String? accessToken}) async {
    final token = accessToken?.trim();
    final query = (token != null && token.isNotEmpty) ? '?access_token=$token' : '';
    try {
      return await _client.fetchBytes('/api/v1/mobile/attachments/$attachmentId/download$query');
    } catch (_) {
      // Fallback: try Odoo standard /web/content/<id> endpoint
      return _client.fetchBytes('/web/content/$attachmentId$query');
    }
  }

  Map<String, dynamic> _responseMap(Object? res) {
    if (res is! Map) {
      throw Failure('Phản hồi attachment không hợp lệ.');
    }
    final map = Map<String, dynamic>.from(res);
    final nested = map['attachment'] ?? map['data'] ?? map['result'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return map;
  }
}

int? _intOrNull(Object? value) {
  if (value == null || value == false) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _stringOrNull(Object? value) {
  if (value == null || value == false) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}
