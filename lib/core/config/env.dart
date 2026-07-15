/// Environment configuration.
///
/// Values are read from `--dart-define` flags. Sensible defaults
/// are kept so `flutter run` works without arguments locally,
/// but production builds should always pass explicit defines.
class Env {
  Env._();

  static const String odooApiBaseUrl = String.fromEnvironment(
    'VCLOUD_ODOO_API_BASE_URL',
    defaultValue: 'http://localhost:8069',
  );

  static const String odooDb = String.fromEnvironment(
    'VCLOUD_ODOO_DB',
    defaultValue: '',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'VCLOUD_FIREBASE_API_KEY',
    defaultValue: '',
  );

  static const String firebaseAppId = String.fromEnvironment(
    'VCLOUD_FIREBASE_APP_ID',
    defaultValue: '',
  );

  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'VCLOUD_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'VCLOUD_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const String firebaseIosBundleId = String.fromEnvironment(
    'VCLOUD_FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.vcloud.vcloud',
  );

  static bool get firebasePushConfigured {
    return firebaseApiKey.isNotEmpty &&
        firebaseAppId.isNotEmpty &&
        firebaseMessagingSenderId.isNotEmpty &&
        firebaseProjectId.isNotEmpty;
  }
}
