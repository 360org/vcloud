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
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  bool _onMessageWired = false;

  Stream<RemoteMessage> get onMessageStream {
    if (kIsWeb || !Env.firebasePushConfigured) {
      // No-op on web/unconfigured; callers still get a valid (empty) stream.
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

  Future<void> registerCurrentDevice() async {
    if (!await _ensureInitialized()) return;

    final messaging = _messaging!;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;

    final installationId = await _installationId();
    final packageInfo = await PackageInfo.fromPlatform();
    await _repository.registerDevice(
      deviceToken: token,
      platform: _platformName,
      deviceName: _deviceName,
      installationId: installationId,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
    await _storage.write(key: _deviceTokenKey, value: token);
  }

  Future<void> unregisterCurrentDevice() async {
    final storedToken = await _storage.read(key: _deviceTokenKey);
    final token = storedToken ?? await _currentTokenIfAvailable();
    if (token == null || token.isEmpty) return;
    await _repository.unregisterDevice(deviceToken: token);
    await _storage.delete(key: _deviceTokenKey);
  }

  /// Releases the foreground FCM subscription. Called on logout so a listener
  /// never survives a session. The broadcast controller itself is left open
  /// so a later login can re-wire [FirebaseMessaging.onMessage] via
  /// [onMessageStream] (the provider owning this service is app-scoped, not
  /// per-session).
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageWired = false;
  }

  Future<bool> _ensureInitialized() async {
    if (kIsWeb || !Env.firebasePushConfigured) return false;
    if (_initialized) return true;

    await Firebase.initializeApp(
      options: VCloudFirebaseOptions.currentPlatform,
    );
    _messaging ??= FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(
      vcloudFirebaseMessagingBackgroundHandler,
    );
    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _initialized = true;
    return true;
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
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android device',
      TargetPlatform.iOS => 'iOS device',
      TargetPlatform.macOS => 'macOS device',
      TargetPlatform.windows => 'Windows device',
      TargetPlatform.linux => 'Linux device',
      TargetPlatform.fuchsia => 'Fuchsia device',
    };
  }
}
