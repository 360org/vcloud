import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import 'firebase_push_options.dart';
import 'push_notification_repository.dart';

const _installationIdKey = 'vcloud_push_installation_id';
const _deviceTokenKey = 'vcloud_push_device_token';

@pragma('vm:entry-point')
Future<void> vcloudFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (!Env.firebasePushConfigured) return;
  await Firebase.initializeApp(options: VCloudFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService({
    PushNotificationRepository? repository,
    FlutterSecureStorage? storage,
    this._messaging,
  }) : _repository = repository ?? PushNotificationRepository(),
       _storage = storage ?? const FlutterSecureStorage();

  final PushNotificationRepository _repository;
  final FlutterSecureStorage _storage;
  FirebaseMessaging? _messaging;

  bool _initialized = false;

  /// Broadcast sink for foreground FCM messages. Lazily wired to
  /// [FirebaseMessaging.onMessage] on first access on native platforms; on
  /// web (or when FCM isn't configured) it stays an empty stream so callers
  /// can subscribe unconditionally without per-platform branches.
  ///
  /// This service is a dumb transport — it surfaces `RemoteMessage`s and does
  /// no cache invalidation. The auth controller decides what to refetch.
  final StreamController<RemoteMessage> _onMessageController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _onMessageOpenedAppController =
      StreamController<RemoteMessage>.broadcast();
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  bool _onMessageWired = false;
  bool _onMessageOpenedAppWired = false;

  Stream<RemoteMessage> get onMessageStream {
    if (!Env.firebasePushConfigured) {
      return const Stream<RemoteMessage>.empty();
    }
    _ensureInitialized().then((ok) {
      if (!ok || _onMessageWired) return;
      _onMessageWired = true;
      _onMessageSubscription = FirebaseMessaging.onMessage.listen(
        _onMessageController.add,
        onError: _onMessageController.addError,
      );
    });
    return _onMessageController.stream;
  }

  Stream<RemoteMessage> get onMessageOpenedAppStream {
    if (!Env.firebasePushConfigured) {
      return const Stream<RemoteMessage>.empty();
    }
    _ensureInitialized().then((ok) {
      if (!ok || _onMessageOpenedAppWired) return;
      _onMessageOpenedAppWired = true;
      _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _onMessageOpenedAppController.add,
        onError: _onMessageOpenedAppController.addError,
      );
    });
    return _onMessageOpenedAppController.stream;
  }

  Future<RemoteMessage?> getInitialMessage() async {
    if (!await _ensureInitialized()) return null;
    return _messaging?.getInitialMessage();
  }

  bool _isRegistering = false;

  Future<String?> registerCurrentDevice() async {
    if (_isRegistering) return _currentTokenIfAvailable();
    _isRegistering = true;

    try {
      if (!await _ensureInitialized()) return null;

      final messaging = _messaging!;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        throw Exception('Quyền nhận thông báo bị từ chối trong Cài đặt của máy.');
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          for (int i = 0; i < 15; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
      }

      // Lắng nghe token refresh tự động
      messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isNotEmpty) {
          try {
            final installationId = await _installationId();
            final packageInfo = await PackageInfo.fromPlatform();
            await _repository.registerDevice(
              deviceToken: newToken,
              platform: _platformName,
              deviceName: _deviceName,
              installationId: installationId,
              appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
            );
            await _storage.write(key: _deviceTokenKey, value: newToken);
          } catch (_) {}
        }
      });

      String? token;
      for (int retry = 0; retry < 3; retry++) {
        try {
          token = await messaging.getToken();
          if (token != null && token.isNotEmpty) break;
        } catch (e) {
          if (retry == 2) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (token == null || token.isEmpty) {
        throw Exception('FCM Token trả về rỗng từ Firebase.');
      }

      final installationId = await _installationId();
      final packageInfo = await PackageInfo.fromPlatform();

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 [PUSH NOTIFICATION TOKEN REGISTERED]');
      debugPrint('📱 Platform       : $_platformName');
      debugPrint('🏷️ Device Name    : $_deviceName');
      debugPrint('🆔 Installation ID: $installationId');
      debugPrint('📦 App Version    : ${packageInfo.version}+${packageInfo.buildNumber}');
      debugPrint('🔑 FCM Token      :\n$token');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      await _repository.registerDevice(
        deviceToken: token,
        platform: _platformName,
        deviceName: _deviceName,
        installationId: installationId,
        appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      );
      await _storage.write(key: _deviceTokenKey, value: token);
      return token;
    } finally {
      _isRegistering = false;
    }
  }

  Future<Map<String, String>> getDeviceInfo() async {
    final installationId = await _installationId();
    final packageInfo = await PackageInfo.fromPlatform();
    final storedToken = await _storage.read(key: _deviceTokenKey);
    final token = storedToken ?? await _currentTokenIfAvailable() ?? 'Chưa tạo token';

    return {
      'platform': _platformName,
      'deviceName': _deviceName,
      'installationId': installationId,
      'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
      'token': token,
    };
  }

  Future<void> unregisterCurrentDevice() async {
    final storedToken = await _storage.read(key: _deviceTokenKey);
    final token = storedToken ?? await _currentTokenIfAvailable();
    if (token == null || token.isEmpty) return;
    await _repository.unregisterDevice(deviceToken: token);
    await _storage.delete(key: _deviceTokenKey);
  }

  /// Releases FCM subscriptions. Called on logout so a listener
  /// never survives a session.
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageWired = false;
    _onMessageOpenedAppSubscription?.cancel();
    _onMessageOpenedAppSubscription = null;
    _onMessageOpenedAppWired = false;
  }

  Future<bool> _ensureInitialized() async {
    if (!Env.firebasePushConfigured) return false;
    if (_initialized) return true;

    try {
      await Firebase.initializeApp(
        options: VCloudFirebaseOptions.currentPlatform,
      );
      _messaging ??= FirebaseMessaging.instance;
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          vcloudFirebaseMessagingBackgroundHandler,
        );
      }
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('Firebase push init error: $e');
      return false;
    }
  }

  Future<String?> _currentTokenIfAvailable() async {
    if (!await _ensureInitialized()) return null;
    return _messaging!.getToken();
  }

  Future<String> _installationId() async {
    final existing = await _storage.read(key: _installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await _storage.write(key: _installationIdKey, value: generated);
    return generated;
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  static String get _deviceName {
    if (kIsWeb) return 'Web Browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android device',
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.macOS => 'macOS device',
      TargetPlatform.windows => 'Windows device',
      TargetPlatform.linux => 'Linux device',
      TargetPlatform.fuchsia => 'Fuchsia device',
    };
  }
}
