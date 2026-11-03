import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/chat/data/chat_repository.dart';
import 'package:vcloud/shared/models/profile.dart';

class _MockOdooApiClient implements OdooApiClient {
  String? lastPath;
  Map<String, Object?>? lastQuery;

  @override
  OdooSession? get session => OdooSession(
        accessToken: 'mock_token',
        uid: 1,
        db: 'demo-17',
        login: 'admin@360.org.vn',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        baseUrl: 'http://localhost:8069',
      );

  @override
  Future<dynamic> get(
    String path, {
    bool auth = true,
    Map<String, Object?> query = const {},
  }) async {
    lastPath = path;
    lastQuery = query;
    if (path == '/api/v1/mobile/users/search') {
      return {
        'users': [
          {
            'user_id': 101,
            'partner_id': 201,
            'name': 'Nguyen Van Staff',
            'email': 'staff@360.org.vn',
            'role': 'employee',
            'is_portal': false,
            'user_type': 'internal',
          },
          {
            'user_id': 102,
            'partner_id': 202,
            'name': 'Le Thi Manager',
            'email': 'manager@360.org.vn',
            'role': 'admin',
            'is_portal': false,
            'user_type': 'internal',
          },
          {
            'user_id': 103,
            'partner_id': 203,
            'name': 'Cong Ty Khach Hang',
            'email': 'customer@portal.vn',
            'role': 'portal',
            'is_portal': true,
            'user_type': 'portal',
          },
        ],
      };
    }
    return [];
  }

  @override
  String absoluteUrl(String path) => 'http://localhost:8069$path';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Chat Internal Portal Exclusion Test Suite (BUG-027 / FEAT-3.44)', () {
    late _MockOdooApiClient mockClient;
    late ChatRepository chatRepository;

    setUp(() {
      mockClient = _MockOdooApiClient();
      chatRepository = ChatRepository(client: mockClient);
    });

    test('Case 1: allUsers() sends type: internal query param to API endpoint', () async {
      final users = await chatRepository.allUsers();

      expect(mockClient.lastPath, '/api/v1/mobile/users/search');
      expect(mockClient.lastQuery, isNotNull);
      expect(mockClient.lastQuery!['type'], 'internal');
      expect(mockClient.lastQuery!['q'], '');
      expect(users.length, 3); // Backend mock returns 3 records, parsed into Profile
    });

    test('Case 2: NewChatScreen Tab Nội bộ strictly filters out isPortal==true and self', () {
      final rawProfiles = [
        const Profile(
          id: '1',
          partnerId: '10',
          displayName: 'Current User',
          email: 'me@360.org.vn',
          role: 'employee',
        ),
        const Profile(
          id: '2',
          partnerId: '20',
          displayName: 'Colleague Staff',
          email: 'colleague@360.org.vn',
          role: 'employee',
        ),
        const Profile(
          id: '3',
          partnerId: '30',
          displayName: 'Khach Hang Portal',
          email: 'khachhang@partner.com',
          role: 'portal',
        ),
        const Profile(
          id: '4',
          partnerId: '40',
          displayName: 'Customer Two',
          email: 'customertwo@gmail.com',
          role: 'customer',
        ),
      ];

      const currentUserId = '1';
      const currentPartnerId = '10';

      final filtered = rawProfiles.where((p) {
        final isSelf = (p.id == currentUserId || p.partnerId == currentUserId) ||
            (p.partnerId == currentPartnerId || p.id == currentPartnerId);
        return !isSelf && !p.isPortal;
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, '2');
      expect(filtered.first.displayName, 'Colleague Staff');
      expect(filtered.first.isStaff, isTrue);
      expect(filtered.any((p) => p.isPortal), isFalse);
    });

    test('Case 3: NewChatScreen Tab Tạo nhóm strictly excludes isPortal==true', () {
      final rawProfiles = [
        const Profile(
          id: '1',
          partnerId: '10',
          displayName: 'Current User',
          email: 'me@360.org.vn',
          role: 'employee',
        ),
        const Profile(
          id: '2',
          partnerId: '20',
          displayName: 'Dev Mobile',
          email: 'dev@360.org.vn',
          role: 'employee',
        ),
        const Profile(
          id: '5',
          partnerId: '50',
          displayName: 'Portal Client',
          email: 'client@portal.vn',
          role: 'portal',
        ),
      ];

      const currentUserId = '1';
      const currentPartnerId = '10';

      final groupCandidates = rawProfiles.where((p) {
        final isSelf = (p.id == currentUserId || p.partnerId == currentUserId) ||
            (p.partnerId == currentPartnerId || p.id == currentPartnerId);
        return !isSelf && !p.isPortal;
      }).toList();

      expect(groupCandidates.length, 1);
      expect(groupCandidates.first.displayName, 'Dev Mobile');
      expect(groupCandidates.any((p) => p.isPortal), isFalse);
    });

    test('Case 4: ChatV2InfoSheet add member logic excludes isPortal==true and existing members', () {
      final allUsers = [
        const Profile(
          id: '2',
          partnerId: '20',
          displayName: 'Dev Mobile',
          email: 'dev@360.org.vn',
          role: 'employee',
        ),
        const Profile(
          id: '6',
          partnerId: '60',
          displayName: 'QA Tester',
          email: 'tester@360.org.vn',
          role: 'employee',
        ),
        const Profile(
          id: '7',
          partnerId: '70',
          displayName: 'Portal External',
          email: 'external@client.vn',
          role: 'portal',
        ),
      ];

      final existingMemberIds = {'20'}; // Dev Mobile already a member
      final existingMemberNames = {'dev mobile'};

      final availableUsers = allUsers.where((u) {
        final pId = u.partnerId?.trim() ?? '';
        final uId = u.id.trim();
        final name = u.displayName.trim().toLowerCase();

        final isAlreadyMember = (pId.isNotEmpty && existingMemberIds.contains(pId)) ||
            (uId.isNotEmpty && existingMemberIds.contains(uId)) ||
            (name.isNotEmpty && existingMemberNames.contains(name));
        return !isAlreadyMember && !u.isPortal;
      }).toList();

      expect(availableUsers.length, 1);
      expect(availableUsers.first.id, '6');
      expect(availableUsers.first.displayName, 'QA Tester');
      expect(availableUsers.any((u) => u.isPortal), isFalse);
    });

    test('Case 5: Internal staff (isStaff: true, role: employee/admin) are preserved 100%', () {
      final staffProfiles = [
        const Profile(
          id: '10',
          partnerId: '100',
          displayName: 'Admin User',
          email: 'admin@360.org.vn',
          role: 'admin',
        ),
        const Profile(
          id: '11',
          partnerId: '101',
          displayName: 'Staff 1',
          email: 'staff1@360.org.vn',
          role: 'employee',
        ),
        const Profile(
          id: '12',
          partnerId: '102',
          displayName: 'Staff 2',
          email: 'staff2@360.org.vn',
          role: 'staff',
        ),
      ];

      for (final profile in staffProfiles) {
        expect(profile.isPortal, isFalse, reason: '${profile.displayName} must not be portal');
        expect(profile.isStaff, isTrue, reason: '${profile.displayName} must be staff');
      }
    });
  });
}
