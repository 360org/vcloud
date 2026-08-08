import 'dart:typed_data';

/// Stub implementation for non-web (iOS/Android native) platforms.
void saveToWebLocalStorage(String key, Uint8List bytes) {}

Uint8List? getFromWebLocalStorage(String key) => null;

int getWebCacheSizeInBytes() => 0;

void clearWebLocalStorage() {}
