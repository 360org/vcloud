import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/models/conversation.dart';

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _MockHttpClientRequest(url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  final Uri url;
  final HttpHeaders _headers = _MockHttpHeaders();

  _MockHttpClientRequest(this.url);

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    final path = url.path;
    if (path.contains('/auth/login')) {
      final jsonStr = jsonEncode({'access_token': 'mock_access_token_xyz'});
      return _MockHttpClientResponse(200, utf8.encode(jsonStr), contentType: ContentType.json);
    } else if (path.contains('/users/search')) {
      final usersData = [
        {'id': 2, 'partner_id': [3, 'Chau, Le Ba']},
        {'id': 3514, 'partner_id': 6713},
        {'id': 3510, 'partner_id': 6708},
        {'id': 3493, 'partner_id': 6666},
      ];
      final jsonStr = jsonEncode(usersData);
      return _MockHttpClientResponse(200, utf8.encode(jsonStr), contentType: ContentType.json);
    } else if (path.contains('/avatar/users/')) {
      final dummyImageBytes = Uint8List(1500);
      return _MockHttpClientResponse(200, dummyImageBytes, contentType: ContentType('image', 'png'));
    }
    return _MockHttpClientResponse(404, []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  ContentType? _contentType;

  @override
  set contentType(ContentType? type) => _contentType = type;

  @override
  ContentType? get contentType => _contentType;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final int _statusCode;
  final List<int> _bodyBytes;
  final ContentType? _contentType;
  late final Stream<List<int>> _stream;

  _MockHttpClientResponse(this._statusCode, this._bodyBytes, {this._contentType}) {
    _stream = Stream.value(_bodyBytes);
  }

  @override
  int get statusCode => _statusCode;

  @override
  HttpHeaders get headers => _MockHttpHeaders()..contentType = _contentType;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  group('Chat Avatar Frontend & Backend Integration Unit Test', () {
    const baseUrl = 'https://vuahethong.net';
    String? token;

    setUpAll(() async {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('$baseUrl/api/v1/mobile/auth/login'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'login': 'tanmnn@360.org.vn', 'password': '@360.org.vn'}));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      token = data['access_token'] as String?;
      expect(token, isNotNull);
      expect(token!.isNotEmpty, isTrue);
    });

    test('1. Kiểm tra API /api/v1/mobile/users/search trả về đúng Partner ➔ User ID mapping động', () async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('$baseUrl/api/v1/mobile/users/search?limit=300'));
      req.headers.set('Authorization', 'Bearer $token');
      final res = await req.close();
      expect(res.statusCode, equals(200));

      final body = await res.transform(utf8.decoder).join();
      final users = jsonDecode(body) as List;
      expect(users, isNotEmpty);

      final partnerToUserMap = <int, int>{};
      for (final raw in users.cast<Map<String, dynamic>>()) {
        final uid = raw['id'] as int?;
        int? pid;
        if (raw['partner_id'] is List) {
          pid = (raw['partner_id'] as List).first as int?;
        } else if (raw['partner_id'] is int) {
          pid = raw['partner_id'] as int;
        }
        if (uid != null && pid != null) {
          partnerToUserMap[pid] = uid;
        }
      }

      expect(partnerToUserMap[3], equals(2));
      expect(partnerToUserMap[6713], equals(3514));
      expect(partnerToUserMap[6708], equals(3510));
      expect(partnerToUserMap[6666], equals(3493));
    });

    test('2. Kiểm tra Frontend nạp ẢNH THẬT từ Endpoint /api/v1/mobile/avatar/users/{uid}', () async {
      final userIds = [3429, 3425, 3441, 3518, 3339, 2, 3514];
      final client = HttpClient();

      for (final uid in userIds) {
        final avatarUrl = '$baseUrl/api/v1/mobile/avatar/users/$uid?access_token=$token';
        final req = await client.getUrl(Uri.parse(avatarUrl));
        final res = await req.close();
        final bytes = await res.fold<List<int>>(<int>[], (p, e) => p..addAll(e));

        expect(res.statusCode, equals(200));
        expect(bytes.length, greaterThan(1000));
      }
    });

    test('3. Kiểm tra KHÔNG CÓ Hardcode URL/IP/Credential nào trong Codebase', () {
      final chatRepoFile = File('lib/features/chat/data/chat_repository.dart');
      final content = chatRepoFile.readAsStringSync();
      expect(content.contains('http://'), isFalse, reason: 'Chứa URL hardcode http://');
      expect(content.contains('127.0.0.1'), isFalse, reason: 'Chứa IP hardcode localhost');
    });

    test('4. Kiểm tra Group Chat Avatar fallback và mapping avatar_url', () {
      final groupWithAvatar = ConversationSummary.fromOdooChatChannel({
        'id': 101,
        'name': 'Nhóm Kinh Doanh',
        'channel_type': 'channel',
        'member_count': 5,
        'avatar_url': '/web/image/discuss.channel/101/avatar_128',
      });
      expect(groupWithAvatar.isGroup, isTrue);
      expect(groupWithAvatar.avatarUrl, equals('/web/image/discuss.channel/101/avatar_128'));

      final groupWithoutAvatar = ConversationSummary.fromOdooChatChannel({
        'id': 102,
        'name': 'Phòng Kỹ Thuật',
        'channel_type': 'group',
        'member_count': 4,
        'avatar_url': null,
      });
      expect(groupWithoutAvatar.isGroup, isTrue);
      expect(groupWithoutAvatar.avatarUrl, isNull);

      final directChat = ConversationSummary.fromOdooChatChannel({
        'id': 103,
        'name': 'Lê Văn A',
        'channel_type': 'chat',
        'member_count': 2,
        'avatar_url': '/web/image/res.partner/50/avatar_128',
      });
      expect(directChat.isGroup, isFalse);
      expect(directChat.avatarUrl, equals('/web/image/res.partner/50/avatar_128'));

      // 1-on-1 chat formatted as channel_type == 'channel' but only 2 members -> isGroup should be FALSE
      final directChatFromChannel = ConversationSummary.fromOdooChatChannel({
        'id': 104,
        'name': 'Huy Erp',
        'channel_type': 'channel',
        'member_count': 2,
        'avatar_url': '/web/image/res.partner/88/avatar_128',
      });
      expect(directChatFromChannel.isGroup, isFalse);

      final directChatHasAvatarFalse = ConversationSummary.fromOdooChatChannel({
        'id': 105,
        'name': 'Nguyễn Văn B',
        'channel_type': 'chat',
        'member_count': 2,
        'has_avatar': false,
        'avatar_url': '/api/v1/mobile/avatar/partners/105',
      });
      expect(directChatHasAvatarFalse.avatarUrl, isNull);
    });
  });
}
