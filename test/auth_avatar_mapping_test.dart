import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/auth/data/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  test('AuthRepository uses signed avatar URL from auth me', () async {
    final client = _FakeOdooApiClient(
      profile: <String, dynamic>{
        'id': 2,
        'login': 'demo@example.com',
        'name': 'Demo User',
        'partner_id': 3,
        'avatar_128_url':
            'http://localhost:8069/web/image/res.partner/3/avatar_128/128x128?access_token=abc',
      },
    );
    final repo = AuthRepository(client: client);

    final user = await repo.signIn(
      email: 'demo@example.com',
      password: 'secret',
    );

    expect(
      user.userMetadata['avatar_url'],
      '/api/v1/mobile/avatar/users/2?access_token=token',
    );
    expect(client.getPaths, isNot(contains('/api/v1/res.partner/3')));
  });
}

class _FakeOdooApiClient extends OdooApiClient {
  _FakeOdooApiClient({required this.profile})
    : super(baseUrl: 'https://example.test');

  final Map<String, dynamic> profile;
  final getPaths = <String>[];

  @override
  Future<OdooSession> login({
    required String login,
    required String password,
    String? db,
    int? tenantId,
  }) async {
    return OdooSession(
      accessToken: 'token',
      uid: 2,
      db: db ?? 'demo',
      login: login,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      baseUrl: 'https://tenant.example.test',
      partnerId: 3,
    );
  }

  @override
  Future<Map<String, dynamic>?> currentUserProfile() async {
    return profile;
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    getPaths.add(path);
    return null;
  }
}
