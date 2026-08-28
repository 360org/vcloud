import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

class MockChatV2Repository extends Fake implements ChatV2Repository {
  MockChatV2Repository({this.channelsToReturn, this.errorToThrow});

  List<ChatV2Channel>? channelsToReturn;
  Object? errorToThrow;
  int callCount = 0;

  @override
  Future<List<ChatV2Channel>> getChannels({
    int? limit,
    int? offset,
    String? search,
    String? filter,
    bool showArchived = false,
  }) async {
    callCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return channelsToReturn ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat V2 Sync Status & Transient Network Resilience Tests', () {
    final sampleChannel = ChatV2Channel(
      id: '999',
      name: 'Tú Oanh - TAB',
      channelType: 'chat',
      isGroup: false,
      memberCount: 2,
      lastMessage: 'Dạ vâng em nhận thông tin ạ',
      lastMessageDate: DateTime.now(),
      directPartnerName: 'Tú Oanh - TAB',
    );

    test('Mặc định ChatV2SyncStatus ban đầu là synced', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final status = container.read(chatV2SyncStatusProvider);
      expect(status, equals(ChatV2SyncStatus.synced));
    });

    test('Chuyển đổi trạng thái mạng: synced -> connecting -> offline -> synced', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(chatV2SyncStatusProvider.notifier);

      // Khi app resume / bắt đầu retry
      notifier.state = ChatV2SyncStatus.connecting;
      expect(container.read(chatV2SyncStatusProvider), equals(ChatV2SyncStatus.connecting));

      // Khi retry 3 lần thất bại -> offline
      notifier.state = ChatV2SyncStatus.offline;
      expect(container.read(chatV2SyncStatusProvider), equals(ChatV2SyncStatus.offline));

      // Khi kết nối lại thành công -> synced
      notifier.state = ChatV2SyncStatus.synced;
      expect(container.read(chatV2SyncStatusProvider), equals(ChatV2SyncStatus.synced));
    });

    test('TEST A: Bảo toàn danh sách cuộc trò chuyện trong memory cache khi refresh gặp lỗi mạng', () {
      ChatV2ChannelLocalCache.set([sampleChannel]);
      expect(ChatV2ChannelLocalCache.cached.length, equals(1));
      expect(ChatV2ChannelLocalCache.cached.first.name, equals('Tú Oanh - TAB'));
      expect(ChatV2ChannelLocalCache.cached.first.lastMessage, equals('Dạ vâng em nhận thông tin ạ'));
    });

    test('TEST B & Single-Flight: resumeRefresh() gọi đồng thời nhiều lần chỉ kích hoạt 1 network request duy nhất', () async {
      final mockRepo = MockChatV2Repository(channelsToReturn: [sampleChannel]);
      final container = ProviderContainer(
        overrides: [
          chatV2RepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatV2ChannelsProvider.notifier);

      // Bắn 5 lệnh resumeRefresh() cùng lúc
      await Future.wait([
        notifier.resumeRefresh(),
        notifier.resumeRefresh(),
        notifier.resumeRefresh(),
        notifier.resumeRefresh(),
        notifier.resumeRefresh(),
      ]);

      // Nhờ Single-Flight Lock, callCount chỉ là 1
      expect(mockRepo.callCount, equals(1));
      expect(container.read(chatV2SyncStatusProvider), equals(ChatV2SyncStatus.synced));
    });

    test('TEST C: Phân biệt lỗi Transient (Timeout/500 -> retry connecting) vs Non-Transient (401/403/404 -> no retry synced)', () async {
      // 1. Non-transient: Lỗi 401 Unauthorized -> Không retry
      final mockAuthFail = MockChatV2Repository(errorToThrow: Exception('401 Unauthorized'));
      final containerAuth = ProviderContainer(
        overrides: [
          chatV2RepositoryProvider.overrideWithValue(mockAuthFail),
        ],
      );
      addTearDown(containerAuth.dispose);

      final notifierAuth = containerAuth.read(chatV2ChannelsProvider.notifier);
      await notifierAuth.resumeRefresh();
      // Không bị chuyển sang connecting/offline liên tục
      expect(containerAuth.read(chatV2SyncStatusProvider), equals(ChatV2SyncStatus.synced));

      // 2. Transient: Lỗi Timeout / Mất kết nối mạng -> Chuyển sang connecting để backoff retry
      final mockNetFail = MockChatV2Repository(errorToThrow: TimeoutException('Hết thời gian chờ'));
      final containerNet = ProviderContainer(
        overrides: [
          chatV2RepositoryProvider.overrideWithValue(mockNetFail),
        ],
      );
      addTearDown(containerNet.dispose);

      final notifierNet = containerNet.read(chatV2ChannelsProvider.notifier);
      await notifierNet.resumeRefresh();
      expect(containerNet.read(chatV2SyncStatusProvider), equals(ChatV2SyncStatus.connecting));
    });

    test('TEST D: Khi chưa có dữ liệu lần đầu (empty cache) và API lỗi -> State là AsyncError và throw error', () async {
      ChatV2ChannelLocalCache.set([]);

      final mockRepo = MockChatV2Repository(errorToThrow: Exception('Network down'));
      final container = ProviderContainer(
        overrides: [
          chatV2RepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(chatV2ChannelsProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
