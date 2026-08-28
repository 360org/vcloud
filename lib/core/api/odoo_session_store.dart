import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'odoo_session.dart';

class OdooSessionStore {
  OdooSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'vcloud_odoo_session';

  final FlutterSecureStorage _storage;

  Future<OdooSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return OdooSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      try {
        await _storage.delete(key: _key);
      } catch (_) {}
      return null;
    }
  }

  Future<void> write(OdooSession session) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
