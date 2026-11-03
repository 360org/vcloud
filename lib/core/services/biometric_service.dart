import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
);

/// [Feature 1.13]: Service quản lý xác thực sinh trắc học (Vân tay / Face ID)
/// và bảo vệ thông tin đăng nhập trong phần cứng Keystore / Keychain.
class BiometricService {
  BiometricService({FlutterSecureStorage? storage, LocalAuthentication? auth})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: false,
              ),
            ),
        _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _biometricEnabledKey = 'biometric_auth_enabled';
  static const _biometricLoginKey = 'biometric_login_user';
  static const _biometricPasswordKey = 'biometric_login_secret';
  static const _biometricDbKey = 'biometric_login_database';

  /// Kiểm tra phần cứng thiết bị có hỗ trợ cảm biến sinh trắc học không
  Future<bool> isHardwareAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      // ponytail: Fallback cho thiết bị di động hỗ trợ xác thực màn hình khoá
      return defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
    }
  }

  /// Kiểm tra người dùng đã bật đăng nhập bằng sinh trắc học trong App chưa
  Future<bool> isBiometricEnabled() async {
    try {
      final val = await _storage.read(key: _biometricEnabledKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Lưu thông tin đăng nhập mã hoá vào SecureStorage khi bật sinh trắc học
  Future<void> enableBiometrics({
    required String login,
    required String password,
    required String db,
  }) async {
    try {
      await _storage.write(key: _biometricEnabledKey, value: 'true');
      await _storage.write(key: _biometricLoginKey, value: login.trim());
      await _storage.write(key: _biometricPasswordKey, value: password);
      await _storage.write(key: _biometricDbKey, value: db.trim());
    } catch (e, st) {
      debugPrint('🚨 [BiometricService.enableBiometrics] Error: $e\n$st');
    }
  }

  /// Huỷ kích hoạt sinh trắc học và xoá khoá bảo mật
  Future<void> disableBiometrics() async {
    try {
      await _storage.delete(key: _biometricEnabledKey);
      await _storage.delete(key: _biometricLoginKey);
      await _storage.delete(key: _biometricPasswordKey);
      await _storage.delete(key: _biometricDbKey);
    } catch (e, st) {
      debugPrint('🚨 [BiometricService.disableBiometrics] Error: $e\n$st');
    }
  }

  /// Lấy thông tin đăng nhập đã lưu trong Keystore
  Future<Map<String, String>?> getCredentials() async {
    try {
      final enabled = await isBiometricEnabled();
      if (!enabled) return null;
      final login = await _storage.read(key: _biometricLoginKey);
      final password = await _storage.read(key: _biometricPasswordKey);
      final db = await _storage.read(key: _biometricDbKey);
      if (login != null && login.isNotEmpty && password != null && password.isNotEmpty) {
        return {
          'login': login,
          'password': password,
          'db': db ?? '',
        };
      }
    } catch (e, st) {
      debugPrint('🚨 [BiometricService.getCredentials] Error: $e\n$st');
    }
    return null;
  }

  /// Yêu cầu người dùng xác thực vân tay hoặc khuôn mặt
  Future<bool> authenticate({
    String reason = 'Xác thực vân tay / Face ID để đăng nhập Vua Hệ Thống',
  }) async {
    try {
      if (!kIsWeb) {
        return await _auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            useErrorDialogs: true,
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [BiometricService.authenticate] Native local_auth exception: $e');
    }
    return false;
  }
}
