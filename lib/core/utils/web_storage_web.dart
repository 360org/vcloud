import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web implementation for LocalStorage persistent attachment cache.
void saveToWebLocalStorage(String key, Uint8List bytes) {
  // Chỉ lưu thumbnail hoặc file cực nhỏ (< 64KB) vào localStorage để tránh QuotaExceededError (5MB limit)
  if (bytes.length > 64 * 1024) return;

  try {
    final b64 = base64Encode(bytes);
    web.window.localStorage.setItem('vcloud_att_$key', b64);
  } catch (e) {
    // Nếu gặp QuotaExceededError, tự động dọn sạch rác cache attachment cũ trong localStorage
    clearWebLocalStorage();
    debugPrint('LocalStorage save skipped & cleared cache: $e');
  }
}

Uint8List? getFromWebLocalStorage(String key) {
  try {
    final storedB64 = web.window.localStorage.getItem('vcloud_att_$key');
    if (storedB64 != null && storedB64.isNotEmpty) {
      return base64Decode(storedB64);
    }
  } catch (_) {}
  return null;
}

int getWebCacheSizeInBytes() {
  int totalBytes = 0;
  try {
    final storage = web.window.localStorage;
    final length = storage.length;
    for (int i = 0; i < length; i++) {
      final k = storage.key(i);
      if (k != null && k.startsWith('vcloud_att_')) {
        final val = storage.getItem(k);
        if (val != null) {
          totalBytes += val.length;
        }
      }
    }
  } catch (_) {}
  return totalBytes;
}

void clearWebLocalStorage() {
  try {
    final storage = web.window.localStorage;
    final keysToRemove = <String>[];
    final length = storage.length;
    for (int i = 0; i < length; i++) {
      final k = storage.key(i);
      if (k != null && k.startsWith('vcloud_att_')) {
        keysToRemove.add(k);
      }
    }
    for (final k in keysToRemove) {
      storage.removeItem(k);
    }
  } catch (_) {}
}
