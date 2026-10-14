import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'odoo_session.dart';

class OdooSessionStore {
  OdooSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: false,
              ),
            );

  static const _legacyStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: false,
    ),
  );

  static const _key = 'vcloud_odoo_session';

  final FlutterSecureStorage _storage;
  OdooSession? _cachedSession;

  Future<OdooSession?> read() async {
    // 1. Fast in-memory tier (resilient against temporary Samsung Knox lock)
    if (_cachedSession != null && !_cachedSession!.isExpired) {
      return _cachedSession;
    }

    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } catch (e) {
      debugPrint('[OdooSessionStore] Primary secure storage read error: $e');
    }

    // 2. Migration fallback: read from legacy storage without encryptedSharedPreferences
    if (raw == null || raw.isEmpty) {
      try {
        raw = await _legacyStorage.read(key: _key);
        if (raw != null && raw.isNotEmpty) {
          // Seamlessly migrate to secure storage with encryptedSharedPreferences
          await _storage.write(key: _key, value: raw);
        }
      } catch (_) {}
    }

    if (raw == null || raw.isEmpty) return _cachedSession;

    try {
      final session = OdooSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      _cachedSession = session;
      return session;
    } on FormatException catch (e) {
      debugPrint('[OdooSessionStore] Corrupted JSON in session storage: $e');
      try {
        await _storage.delete(key: _key);
        await _legacyStorage.delete(key: _key);
      } catch (_) {}
      _cachedSession = null;
      return null;
    } catch (e) {
      debugPrint('[OdooSessionStore] Error parsing stored session: $e');
      return _cachedSession;
    }
  }

  Future<void> write(OdooSession session) async {
    _cachedSession = session;
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    } catch (e) {
      debugPrint('[OdooSessionStore] write error: $e');
    }
  }

  Future<void> clear() async {
    _cachedSession = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    try {
      await _legacyStorage.delete(key: _key);
    } catch (_) {}
  }
}
