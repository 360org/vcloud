import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/api/odoo_session.dart';
import '../../../core/notifications/push_notification_controller.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/services/global_state_reset_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../profile/application/theme_controller.dart';
import '../data/auth_repository.dart';
import '../data/db_info.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

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
        unawaited(GlobalStateResetService.clearAllUserDataOnLogout(ref: ref));
        state = const AsyncData(null);
      }
    };
    try {
      final user = await _repo.currentUser();
      if (user != null) {
        _syncThemeFromUser(user);
        unawaited(_registerPushDevice().catchError((_) {}));
      }
      return user;
    } catch (e, st) {
      debugPrint('[AuthController] build error: $e\n$st');
      return null;
    }
  }

  /// [Bước 2 Theo Kiến Trúc Chuẩn Của Sếp Tân]
  /// Tra cứu danh sách DB từ Master Router chỉ với login.
  /// ⚠️ TUYỆT ĐỐI KHÔNG BẮT GỬI PASSWORD LÊN MASTER!
  Future<List<DbInfo>> lookupDb(
    String login, {
    String? preferredDb,
  }) {
    return _repo.lookupDb(login, preferredDb: preferredDb);
  }

  /// Lấy database đã đăng nhập thành công gần nhất từ LocalStorage
  Future<String?> getLastSelectedDb() {
    return _repo.getLastSelectedDb();
  }

  /// Thử xác thực với một DB ứng viên mà không làm thay đổi phiên hiện tại
  Future<OdooSession?> verifyCredentialOnClient({
    required DbInfo db,
    required String login,
    required String password,
  }) {
    return _repo.verifyCredentialOnClient(
      db: db,
      login: login,
      password: password,
    );
  }

  /// Kích hoạt phiên đã xác thực thành công trước đó (Pre-authenticated session)
  Future<void> activateVerifiedSession({
    required DbInfo db,
    required OdooSession session,
    required String login,
  }) async {
    state = const AsyncLoading();
    try {
      await GlobalStateResetService.clearAllUserDataOnLogout(ref: ref);
      final user = await _repo.activateVerifiedSession(
        db: db,
        session: session,
        login: login,
      );
      _syncThemeFromUser(user);
      unawaited(_registerPushDevice().catchError((_) {}));
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Bước 4: Xác thực trực tiếp với Client DB (password gửi thẳng Client DB).
  Future<void> authenticateOnClient({
    required DbInfo db,
    required String login,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await GlobalStateResetService.clearAllUserDataOnLogout(ref: ref);
      final user = await _repo.authenticateOnClient(
        db: db,
        login: login,
        password: password,
      );
      _syncThemeFromUser(user);
      unawaited(_registerPushDevice().catchError((_) {}));
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signIn(String email, String password, {int? tenantId}) async {
    state = const AsyncLoading();
    try {
      await GlobalStateResetService.clearAllUserDataOnLogout(ref: ref);
      final user = await _repo.signIn(
        email: email,
        password: password,
        tenantId: tenantId,
      );
      _syncThemeFromUser(user);
      unawaited(_registerPushDevice().catchError((_) {}));
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
    required String phone,
    bool acceptTerms = true,
    String? confirmPassword,
    int? tenantId,
  }) async {
    state = const AsyncLoading();
    try {
      await GlobalStateResetService.clearAllUserDataOnLogout(ref: ref);
      final user = await _repo.signUp(
        email: email,
        password: password,
        displayName: displayName,
        phone: phone,
        acceptTerms: acceptTerms,
        confirmPassword: confirmPassword,
        tenantId: tenantId,
      );
      _syncThemeFromUser(user);
      unawaited(_registerPushDevice().catchError((_) {}));
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _unregisterPushDevice();
    await GlobalStateResetService.clearAllUserDataOnLogout(ref: ref);
    await _repo.signOut();
    state = const AsyncData(null);
  }

  /// [Feature 1.10]: Gửi yêu cầu đặt lại mật khẩu về email
  Future<String> requestPasswordReset(String login, {String? db, String? baseUrl}) {
    return _repo.requestPasswordReset(login, db: db, baseUrl: baseUrl);
  }

  /// [Feature 1.11]: Xác thực mã OTP 2 lớp (TOTP)
  Future<void> verifyTotp({
    required String login,
    required String password,
    required String totpToken,
    String? db,
    String? targetBaseUrl,
  }) async {
    state = const AsyncLoading();
    try {
      await GlobalStateResetService.clearAllUserDataOnLogout(ref: ref);
      final user = await _repo.verifyTotp(
        login: login,
        password: password,
        totpToken: totpToken,
        db: db,
        targetBaseUrl: targetBaseUrl,
      );
      unawaited(_registerPushDevice().catchError((_) {}));
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// [Feature 1.12]: Đăng nhập qua Google OAuth2 / Social Sign-In
  Future<void> signInWithOAuth({
    required String provider,
    required String accessToken,
    String? idToken,
    String? email,
    String? db,
    String? targetBaseUrl,
  }) async {
    state = const AsyncLoading();
    try {
      await GlobalStateResetService.clearAllUserDataOnLogout(ref: ref);
      final user = await _repo.signInWithOAuth(
        provider: provider,
        accessToken: accessToken,
        idToken: idToken,
        email: email,
        db: db,
        targetBaseUrl: targetBaseUrl,
      );
      unawaited(_registerPushDevice().catchError((_) {}));
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// [Feature 1.13]: Quản lý Sinh trắc học
  Future<bool> isBiometricEnabled() => _repo.isBiometricEnabled();
  Future<Map<String, String>?> getBiometricCredentials() => _repo.getBiometricCredentials();
  Future<void> saveBiometricCredentials({
    required String login,
    required String password,
    required String db,
  }) => _repo.saveBiometricCredentials(login: login, password: password, db: db);
  Future<void> clearBiometricCredentials() => _repo.clearBiometricCredentials();

  Future<void> uploadAvatar(String base64Image) async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    final dataUri = 'data:image/png;base64,$base64Image';
    final current = state.value;
    final currentDb = current?.userMetadata['db']?.toString();
    if (current != null) {
      await _repo.saveLocalAvatar(current.id, dataUri, db: currentDb);
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
        await _repo.saveLocalAvatar(current.id, cacheBustedUrl, db: currentDb);
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
      debugPrint(
        'Remote avatar upload failed, keeping local base64 avatar: $e',
      );
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
        try {
          AppToast.showGlobal(
            type: AppToastType.error,
            title: 'Lỗi đăng ký Push',
            message: e.toString(),
            duration: const Duration(seconds: 10),
          );
        } catch (_) {}
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

  void _syncThemeFromUser(AuthUser? user) {
    if (user == null) return;
    final colorScheme = user.userMetadata['color_scheme'] as String?;
    if (colorScheme != null && colorScheme.isNotEmpty) {
      unawaited(ref.read(themeControllerProvider.notifier).syncServerTheme(colorScheme));
    }
  }

  /// Làm mới hồ sơ người dùng từ server và cập nhật state
  Future<AuthUser?> reloadProfile() async {
    try {
      final user = await _repo.currentUser();
      if (user != null) {
        _syncThemeFromUser(user);
        state = AsyncData(user);
      }
      return user;
    } catch (e, st) {
      debugPrint('[AuthController.reloadProfile] error: $e\n$st');
      return state.valueOrNull;
    }
  }
}
