import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

class InAppNotificationPayload {
  const InAppNotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.channelId,
    this.avatarUrl,
  });

  final String id;
  final String title;
  final String body;
  final String channelId;
  final String? avatarUrl;
}

final inAppNotificationProvider =
    StateNotifierProvider<InAppNotificationNotifier, InAppNotificationPayload?>(
  (ref) => InAppNotificationNotifier(),
);

class InAppNotificationNotifier extends StateNotifier<InAppNotificationPayload?> {
  InAppNotificationNotifier() : super(null);

  Timer? _dismissTimer;

  void show({
    required String title,
    required String body,
    required String channelId,
    String? avatarUrl,
  }) {
    _dismissTimer?.cancel();
    state = InAppNotificationPayload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      channelId: channelId,
      avatarUrl: avatarUrl,
    );

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      dismiss();
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

/// Banner thông báo nổi trong ứng dụng (In-App Floating Banner - Apple HIG)
class InAppNotificationBanner extends ConsumerWidget {
  const InAppNotificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(inAppNotificationProvider);
    if (payload == null) return const SizedBox.shrink();

    final topPadding = MediaQuery.paddingOf(context).top + 12;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            ref.read(inAppNotificationProvider.notifier).dismiss();
            ref.read(routerProvider).go('/chat/${payload.channelId}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.96)
                  : Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.messageCircle,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              payload.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.midnight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            'Vừa xong',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        payload.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ref.read(inAppNotificationProvider.notifier).dismiss();
                  },
                  child: const Icon(
                    LucideIcons.x,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
