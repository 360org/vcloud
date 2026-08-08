import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web/web.dart' as web;

/// Zalo-style Local & Persistent Attachment Cache with Auto Platform Detection.
/// - Web (kIsWeb == true): RAM Cache + LocalStorage (Base64).
/// - Mobile (kIsWeb == false): RAM Cache + physical disk file storage via path_provider.
class LocalAttachmentCache {
  LocalAttachmentCache._();

  static final Map<String, Uint8List> _memCache = <String, Uint8List>{};
  static String? _mobileDirPath;

  /// Clean key name for storage lookup.
  static String _cleanKey(String key) {
    final trimmed = key.trim();
    final basename = trimmed.split('/').last.split('\\').last;
    return basename.isEmpty ? trimmed : basename;
  }

  /// Initialize and return the physical local directory for mobile attachment cache.
  static Future<String?> _getMobileDirPath() async {
    if (kIsWeb) return null;
    if (_mobileDirPath != null) return _mobileDirPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final attDir = Directory('${dir.path}/attachments');
      if (!attDir.existsSync()) {
        attDir.createSync(recursive: true);
      }
      _mobileDirPath = attDir.path;
      return _mobileDirPath;
    } catch (e) {
      debugPrint('Mobile attachment directory error: $e');
      return null;
    }
  }

  /// Save raw file/image bytes into RAM and platform persistent storage.
  static void save(String key, Uint8List bytes) {
    if (key.trim().isEmpty || bytes.isEmpty) return;
    final clean = _cleanKey(key);
    _memCache[clean] = bytes;
    _memCache[key.trim()] = bytes;

    if (kIsWeb) {
      try {
        // Persistent browser LocalStorage on Web (up to ~4MB per file entry)
        if (bytes.length < 4 * 1024 * 1024) {
          final b64 = base64Encode(bytes);
          web.window.localStorage.setItem('vcloud_att_$clean', b64);
        }
      } catch (e) {
        debugPrint('LocalStorage save skipped: $e');
      }
    } else {
      // Mobile Environment (iOS/Android): Save physical file under app documents directory
      _saveMobileFile(clean, bytes);
    }
  }

  static Future<void> _saveMobileFile(String clean, Uint8List bytes) async {
    try {
      final dirPath = await _getMobileDirPath();
      if (dirPath == null) return;
      final file = File('$dirPath/$clean.bin');
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Mobile file save error: $e');
    }
  }

  /// Retrieve cached local bytes from RAM, LocalStorage (Web), or Physical File (Mobile) immediately.
  static Uint8List? get(String? key, {String? altKey}) {
    final keysToTry = <String>[
      if (key != null && key.trim().isNotEmpty) key.trim(),
      if (key != null && key.trim().isNotEmpty) _cleanKey(key),
      if (altKey != null && altKey.trim().isNotEmpty) altKey.trim(),
      if (altKey != null && altKey.trim().isNotEmpty) _cleanKey(altKey),
    ];

    for (final k in keysToTry) {
      // 1. Check RAM memory cache first
      if (_memCache.containsKey(k)) {
        return _memCache[k];
      }

      // 2. Check platform persistent storage
      if (kIsWeb) {
        try {
          final storedB64 = web.window.localStorage.getItem('vcloud_att_$k');
          if (storedB64 != null && storedB64.isNotEmpty) {
            final bytes = base64Decode(storedB64);
            _memCache[k] = bytes; // Populate RAM cache for future accesses
            return bytes;
          }
        } catch (_) {}
      } else {
        // Mobile Environment: Check physical disk file
        try {
          if (_mobileDirPath != null) {
            final file = File('$_mobileDirPath/$k.bin');
            if (file.existsSync()) {
              final bytes = file.readAsBytesSync();
              _memCache[k] = bytes; // Populate RAM cache
              return bytes;
            }
          }
        } catch (_) {}
      }
    }

    // Trigger async initialization for mobile directory if not yet ready
    if (!kIsWeb && _mobileDirPath == null) {
      _getMobileDirPath();
    }

    return null;
  }

  /// Retrieve cached local bytes asynchronously (ensures mobile directory is initialized).
  static Future<Uint8List?> getAsync(String? key, {String? altKey}) async {
    final syncResult = get(key, altKey: altKey);
    if (syncResult != null) return syncResult;

    if (!kIsWeb && _mobileDirPath == null) {
      await _getMobileDirPath();
      return get(key, altKey: altKey);
    }

    return null;
  }

  /// Returns true if [key] exists in local cache.
  static bool has(String? key) {
    return get(key) != null;
  }

  /// Calculate current total cache size in Megabytes (MB).
  static Future<double> getCacheSizeInMB() async {
    int totalBytes = 0;

    if (kIsWeb) {
      try {
        final storage = web.window.localStorage;
        final length = storage.length;
        for (int i = 0; i < length; i++) {
          final key = storage.key(i);
          if (key != null && key.startsWith('vcloud_att_')) {
            final val = storage.getItem(key);
            if (val != null) {
              totalBytes += val.length;
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting Web cache size: $e');
      }
    } else {
      try {
        final dirPath = await _getMobileDirPath();
        if (dirPath != null) {
          final dir = Directory(dirPath);
          if (dir.existsSync()) {
            final files = dir.listSync();
            for (final entity in files) {
              if (entity is File) {
                totalBytes += await entity.length();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting Mobile cache size: $e');
      }
    }

    // Also account for in-memory RAM cache entries
    _memCache.forEach((_, bytes) {
      totalBytes += bytes.length;
    });

    return totalBytes / (1024 * 1024);
  }

  /// Clear all cached attachments in RAM memory and platform persistent storage.
  static Future<void> clearAllCache() async {
    _memCache.clear();

    if (kIsWeb) {
      try {
        final storage = web.window.localStorage;
        final keysToRemove = <String>[];
        final length = storage.length;
        for (int i = 0; i < length; i++) {
          final key = storage.key(i);
          if (key != null && key.startsWith('vcloud_att_')) {
            keysToRemove.add(key);
          }
        }
        for (final key in keysToRemove) {
          storage.removeItem(key);
        }
      } catch (e) {
        debugPrint('Error clearing Web cache: $e');
      }
    } else {
      try {
        final dirPath = await _getMobileDirPath();
        if (dirPath != null) {
          final dir = Directory(dirPath);
          if (dir.existsSync()) {
            final files = dir.listSync();
            for (final entity in files) {
              if (entity is File) {
                await entity.delete();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error clearing Mobile cache: $e');
      }
    }
  }
}
