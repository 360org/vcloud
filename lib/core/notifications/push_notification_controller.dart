import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_notification_repository.dart';
import 'push_notification_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (_) => PushNotificationService(),
);

final pushNotificationRepositoryProvider = Provider<PushNotificationRepository>(
  (_) => PushNotificationRepository(),
);

final mobileNotificationsProvider =
    StreamProvider.autoDispose<MobileNotificationList>(
      (ref) =>
          ref.read(pushNotificationRepositoryProvider).watchNotifications(),
    );
