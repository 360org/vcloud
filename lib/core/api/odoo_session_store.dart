import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'odoo_session.dart';

class OdooSessionStore {
  OdooSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'vcloud_odoo_session';

  final FlutterSecureStorage _storage;

  Future<OdooSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    return OdooSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> write(OdooSession session) {
    return _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() {
    return _storage.delete(key: _key);
  }
}
