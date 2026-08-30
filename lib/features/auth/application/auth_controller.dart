import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/notifications/push_notification_controller.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../chat_v2/application/chat_v2_channels_controller.dart';
import '../../chat_v2/application/chat_v2_messages_controller.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../timesheet/data/timesheet_repository.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

/// Single source of truth for the current Odoo-authenticated user.
final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthUser?> {
  late final AuthRepository _repo;
  late final PushNotificationService _pushNotifications;

  @override
  Future<AuthUser?> build() async {
    _repo = ref.watch(authRepositoryProvider);
    _pushNotifications = ref.watch(pushNotificationServiceProvider);
    OdooApiClient.onSessionExpired = () {
      if (state.valueOrNull != null) {
        state = const AsyncData(null);
      }
    };
    try {
      final user = await _repo.currentUser();
      if (user != null) {
        unawaited(_registerPushDevice());
      }
      return user;
    } catch (e, st) {
      debugPrint('[AuthController] build error: $e\n$st');
      return null;
    }
  }

  Future<void> signIn(String email, String password, {int? tenantId}) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.signIn(
        email: email,
        password: password,
        tenantId: tenantId,
      );
      unawaited(_registerPushDevice());
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    int? tenantId,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        displayName: displayName,
        tenantId: tenantId,
      );
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _unregisterPushDevice();
    ChatV2ChannelLocalCache.clear();
    ChatV2MessageLocalCache.clear();
    TimesheetRepository.clearCache();
    await _repo.signOut();
    state = const AsyncData(null);
  }

  Future<void> uploadAvatar(String base64Image) async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    final dataUri = 'data:image/png;base64,$base64Image';
    final current = state.value;
    if (current != null) {
      await _repo.saveLocalAvatar(current.id, dataUri);
      final updatedMetadata = <String, dynamic>{
        ...current.userMetadata,
        'avatar_url': dataUri,
        'avatar_128_url': dataUri,
        'image_128_url': dataUri,
      };
      state = AsyncData(
        AuthUser(
          id: current.id,
          email: current.email,
          userMetadata: updatedMetadata,
        ),
      );
    }
    try {
      final newUrl = await _repo.uploadAvatar(base64Image);
      if (newUrl.isNotEmpty && current != null) {
        try {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        } catch (_) {}
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sep = newUrl.contains('?') ? '&' : '?';
        final cacheBustedUrl = '$newUrl${sep}t=$timestamp';
        await _repo.saveLocalAvatar(current.id, cacheBustedUrl);
        final updatedMetadata = <String, dynamic>{
          ...current.userMetadata,
          'avatar_url': cacheBustedUrl,
          'avatar_128_url': cacheBustedUrl,
          'image_128_url': cacheBustedUrl,
        };
        state = AsyncData(
          AuthUser(
            id: current.id,
            email: current.email,
            userMetadata: updatedMetadata,
          ),
        );
      }
    } catch (e) {
      debugPrint('Remote avatar upload failed, keeping local base64 avatar: $e');
    }
  }

  bool _isRegisteringPush = false;

  Future<void> _registerPushDevice() async {
    if (_isRegisteringPush) return;
    _isRegisteringPush = true;
    try {
      await _pushNotifications.registerCurrentDevice();
    } catch (e) {
      debugPrint('❌ [PUSH REGISTRATION FAILED]: $e');
      if (!kIsWeb) {
        AppToast.showGlobal(
          type: AppToastType.error,
          title: 'Lỗi đăng ký Push',
          message: e.toString(),
          duration: const Duration(seconds: 10),
        );
      }
    } finally {
      _isRegisteringPush = false;
    }
  }

  Future<void> _unregisterPushDevice() async {
    try {
      await _pushNotifications.unregisterCurrentDevice();
    } catch (e) {
      debugPrint('Push unregister skipped: $e');
    }
  }
}
