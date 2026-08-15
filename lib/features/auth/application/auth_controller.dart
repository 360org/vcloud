import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/notifications/push_notification_controller.dart';
import '../../../core/notifications/push_notification_service.dart';
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
    final user = await _repo.currentUser();
    if (user != null) {
      unawaited(_registerPushDevice());
    }
    return user;
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
    await _repo.signOut();
    state = const AsyncData(null);
  }

  Future<void> uploadAvatar(String base64Image) async {
    final dataUri = 'data:image/png;base64,$base64Image';
    final current = state.value;
    if (current != null) {
      await _repo.saveLocalAvatar(current.id, dataUri);
      final updatedMetadata = <String, dynamic>{
        ...current.userMetadata,
        'avatar_url': dataUri,
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
        final updatedMetadata = <String, dynamic>{
          ...current.userMetadata,
          'avatar_url': newUrl,
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

  Future<void> _registerPushDevice() async {
    try {
      await _pushNotifications.registerCurrentDevice();
    } catch (e) {
      debugPrint('Push registration skipped: $e');
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
