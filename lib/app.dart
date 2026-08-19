import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/push_notification_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/attendance/application/attendance_controller.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/chat_v2/application/chat_v2_channels_controller.dart';
import 'features/home/application/home_summary_controller.dart';
import 'features/profile/application/theme_controller.dart';
import 'features/ticket/application/ticket_controller.dart';

class VCloudApp extends ConsumerStatefulWidget {
  const VCloudApp({super.key});

  @override
  ConsumerState<VCloudApp> createState() => _VCloudAppState();
}

class _VCloudAppState extends ConsumerState<VCloudApp>
    with WidgetsBindingObserver {
  late final StreamSubscription<RemoteMessage> _foregroundPushSubscription;
  StreamSubscription<RemoteMessage>? _openedAppPushSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final pushService = ref.read(pushNotificationServiceProvider);
    _foregroundPushSubscription = pushService.onMessageStream.listen(_onForegroundPush);
    _openedAppPushSubscription = pushService.onMessageOpenedAppStream.listen(_onPushNotificationOpened);

    // Check cold start from push notification
    pushService.getInitialMessage().then((initialMsg) {
      if (initialMsg != null) {
        _onPushNotificationOpened(initialMsg);
      }
    });
  }

  @override
  void dispose() {
    _foregroundPushSubscription.cancel();
    _openedAppPushSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from background → refresh live streams so unread badges
    // and notifications catch up immediately instead of waiting for next poll.
    if (state != AppLifecycleState.resumed) return;
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    ref.invalidate(chatV2ChannelsProvider);
    ref.invalidate(chatV2TotalUnreadProvider);
    ref.invalidate(mobileNotificationsProvider);
    ref.invalidate(attendanceTodayProvider);
    ref.invalidate(attendanceStreamProvider);
    ref.invalidate(mobileDashboardSummaryProvider);
  }

  void _onForegroundPush(RemoteMessage message) {
    final data = message.data;
    final type = (data['event_type'] ?? data['type'] ?? data['model'] ?? '')
        .toString()
        .toLowerCase();

    ref.invalidate(mobileNotificationsProvider);
    ref.invalidate(mobileDashboardSummaryProvider);

    if (type.contains('chat') || type.contains('discuss') || data.containsKey('channel_id')) {
      ref.invalidate(chatV2ChannelsProvider);
      ref.invalidate(chatV2TotalUnreadProvider);
    }

    if (type.contains('attendance') || data.containsKey('attendance_id')) {
      ref.invalidate(attendanceTodayProvider);
      ref.invalidate(attendanceStreamProvider);
    }

    if (type.contains('ticket') || type.contains('helpdesk') || data.containsKey('ticket_id')) {
      ref.invalidate(ticketsProvider);
    }
  }

  void _onPushNotificationOpened(RemoteMessage message) {
    final data = message.data;
    final channelId = data['channel_id'] ?? data['discuss_channel_id'] ?? data['chat_id'];
    final ticketId = data['ticket_id'] ?? data['helpdesk_ticket_id'];

    if (channelId != null && channelId.toString().isNotEmpty) {
      final channelName = data['channel_name'] ?? data['name'] ?? '';
      ref.read(routerProvider).go(
            '/chat/$channelId?name=${Uri.encodeComponent(channelName.toString())}',
          );
    } else if (ticketId != null && ticketId.toString().isNotEmpty) {
      ref.read(routerProvider).go('/tickets/$ticketId');
    } else {
      ref.read(routerProvider).go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'Vcloud',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode.when(
        data: (mode) => mode.themeMode,
        loading: () => ThemeMode.system,
        error: (e, st) => ThemeMode.system,
      ),
      routerConfig: router,
    );
  }
}
