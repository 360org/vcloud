/// Environment configuration.
///
/// Values are read from `--dart-define` flags. Sensible defaults
/// are kept so `flutter run` works without arguments locally,
/// but production builds should always pass explicit defines.
class Env {
  Env._();

  static const String odooApiBaseUrl = String.fromEnvironment(
    'VCLOUD_ODOO_API_BASE_URL',
    defaultValue: 'https://vuahethong.net',
  );

  static const String odooDb = String.fromEnvironment(
    'VCLOUD_ODOO_DB',
    defaultValue: '',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'VCLOUD_FIREBASE_API_KEY',
    defaultValue: 'AIzaSyAFEPKxCmxL5dtKAZD1Xt4d7XiWoHDQ6UY',
  );

  static const String firebaseAppId = String.fromEnvironment(
    'VCLOUD_FIREBASE_APP_ID',
    defaultValue: '1:339448653254:web:1e9d9ec9460c30ce073ec7',
  );

  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'VCLOUD_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '339448653254',
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'VCLOUD_FIREBASE_PROJECT_ID',
    defaultValue: 'vcloud-mobile',
  );

  static const String firebaseIosBundleId = String.fromEnvironment(
    'VCLOUD_FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.w360s.wcloudapp',
  );

  static const String firebaseVapidKey = String.fromEnvironment(
    'VCLOUD_FIREBASE_VAPID_KEY',
    defaultValue: 'BIRf_ttFAM85aTMWm9uRC5Obn8P5xn1k6fH7kj7Kiev0y3WX3WXWe9YnGzcx24IwX3j1kGaqt7fSRIdI-dv-0_U',
  );

  static bool get firebasePushConfigured {
    // Luôn bật vì cấu hình đã được cung cấp trực tiếp trong VCloudFirebaseOptions
    return true;
  }
}
