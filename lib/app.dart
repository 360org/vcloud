import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/push_notification_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/attendance/application/attendance_controller.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/chat/application/conversations_controller.dart';
import 'features/home/application/home_summary_controller.dart';
import 'features/profile/application/theme_controller.dart';

class VCloudApp extends ConsumerStatefulWidget {
  const VCloudApp({super.key});

  @override
  ConsumerState<VCloudApp> createState() => _VCloudAppState();
}

class _VCloudAppState extends ConsumerState<VCloudApp>
    with WidgetsBindingObserver {
  late final StreamSubscription<RemoteMessage> _foregroundPushSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foregroundPushSubscription = ref
        .read(pushNotificationServiceProvider)
        .onMessageStream
        .listen(_onForegroundPush);
  }

  @override
  void dispose() {
    _foregroundPushSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from background → refresh the live streams so unread badges
    // and the bell catch up immediately instead of waiting for the next poll.
    // Skip when logged out to avoid hitting providers that would just error.
    if (state != AppLifecycleState.resumed) return;
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    ref.invalidate(conversationsProvider);
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
    final isAttendanceEvent =
        type.contains('attendance') || data.containsKey('attendance_id');

    ref.invalidate(mobileNotificationsProvider);
    if (!isAttendanceEvent) return;
    ref.invalidate(attendanceTodayProvider);
    ref.invalidate(attendanceStreamProvider);
    ref.invalidate(mobileDashboardSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'world360',
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
