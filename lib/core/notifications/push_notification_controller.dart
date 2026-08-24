import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'push_notification_repository.dart';
import 'push_notification_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (_) => PushNotificationService(),
);

final pushNotificationRepositoryProvider = Provider<PushNotificationRepository>(
  (_) => PushNotificationRepository(),
);

final dismissedNotificationIdsProvider =
    StateNotifierProvider<DismissedNotificationNotifier, Set<String>>((ref) {
  return DismissedNotificationNotifier();
});

class DismissedNotificationNotifier extends StateNotifier<Set<String>> {
  DismissedNotificationNotifier() : super(const {}) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'dismissed_notification_ids_v1';

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        state = decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
  }

  Future<void> dismiss(String key) async {
    final next = {...state, key};
    state = next;
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(next.toList()));
    } catch (_) {}
  }

  Future<void> dismissAll(Iterable<String> keys) async {
    final next = {...state, ...keys};
    state = next;
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(next.toList()));
    } catch (_) {}
  }

  Future<void> clearAllDismissed() async {
    state = const {};
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }
}

final mobileNotificationsProvider =
    StreamProvider.autoDispose<MobileNotificationList>(
      (ref) =>
          ref.read(pushNotificationRepositoryProvider).watchNotifications(),
    );
