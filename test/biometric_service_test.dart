import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:vcloud/core/services/biometric_service.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

class MockLocalAuth extends Fake implements LocalAuthentication {
  bool canCheck = true;
  bool isSupported = true;
  bool authenticateResult = true;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic>? authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    return authenticateResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage mockStorage;
  late MockLocalAuth mockAuth;
  late BiometricService service;

  setUp(() {
    mockStorage = MockSecureStorage();
    mockAuth = MockLocalAuth();
    service = BiometricService(storage: mockStorage, auth: mockAuth);
  });

  group('BiometricService Verification Suite (10 Cases)', () {
    test('Case 1: isHardwareAvailable returns true when canCheckBiometrics is true', () async {
      mockAuth.canCheck = true;
      mockAuth.isSupported = false;
      final available = await service.isHardwareAvailable();
      expect(available, isTrue);
    });

    test('Case 2: isHardwareAvailable returns true when isDeviceSupported is true', () async {
      mockAuth.canCheck = false;
      mockAuth.isSupported = true;
      final available = await service.isHardwareAvailable();
      expect(available, isTrue);
    });

    test('Case 3: isBiometricEnabled returns false initially', () async {
      final enabled = await service.isBiometricEnabled();
      expect(enabled, isFalse);
    });

    test('Case 4: enableBiometrics correctly stores credentials and enables flag', () async {
      await service.enableBiometrics(
        login: 'demo',
        password: 'password123',
        db: 'vcloud_test_v19',
      );
      final enabled = await service.isBiometricEnabled();
      expect(enabled, isTrue);
    });

    test('Case 5: getCredentials retrieves valid credentials from Keystore', () async {
      await service.enableBiometrics(
        login: 'demo_user',
        password: 'secret_password',
        db: 'vuahethong',
      );
      final creds = await service.getCredentials();
      expect(creds, isNotNull);
      expect(creds!['login'], equals('demo_user'));
      expect(creds['password'], equals('secret_password'));
      expect(creds['db'], equals('vuahethong'));
    });

    test('Case 6: getCredentials returns null when biometric is not enabled', () async {
      final creds = await service.getCredentials();
      expect(creds, isNull);
    });

    test('Case 7: disableBiometrics deletes all keys and disables flag', () async {
      await service.enableBiometrics(
        login: 'test@example.com',
        password: 'pwd',
        db: 'test_db',
      );
      expect(await service.isBiometricEnabled(), isTrue);

      await service.disableBiometrics();
      expect(await service.isBiometricEnabled(), isFalse);
      expect(await service.getCredentials(), isNull);
    });

    test('Case 8: authenticate returns true when local_auth succeeds', () async {
      mockAuth.authenticateResult = true;
      final result = await service.authenticate(reason: 'Test biometric');
      expect(result, isTrue);
    });

    test('Case 9: authenticate returns false when user cancels or auth fails', () async {
      mockAuth.authenticateResult = false;
      final result = await service.authenticate(reason: 'Test biometric');
      expect(result, isFalse);
    });

    test('Case 10: enableBiometrics trims login and db strings', () async {
      await service.enableBiometrics(
        login: '   admin@360.org.vn   ',
        password: '  raw_pwd  ',
        db: '   vcloud_test_v19   ',
      );
      final creds = await service.getCredentials();
      expect(creds!['login'], equals('admin@360.org.vn'));
      expect(creds['password'], equals('  raw_pwd  '));
      expect(creds['db'], equals('vcloud_test_v19'));
    });
  });
}
