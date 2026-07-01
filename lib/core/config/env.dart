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
}
