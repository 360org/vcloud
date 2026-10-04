import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Hiển thị BottomSheet lựa chọn thời gian tắt thông báo cho cuộc trò chuyện
Future<int?> showMuteDurationPickerSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const ChatV2MuteDurationSheet(),
  );
}

class ChatV2MuteDurationSheet extends StatelessWidget {
  const ChatV2MuteDurationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final options = [
      const _MuteOption(
        title: 'Trong 1 giờ',
        minutes: 60,
        icon: LucideIcons.clock,
      ),
      const _MuteOption(
        title: 'Trong 8 giờ',
        minutes: 480,
        icon: LucideIcons.clock,
      ),
      const _MuteOption(
        title: 'Trong 24 giờ',
        minutes: 1440,
        icon: LucideIcons.calendar,
      ),
      const _MuteOption(
        title: 'Cho đến khi tôi bật lại',
        minutes: -1,
        icon: LucideIcons.bellOff,
        isDestructive: true,
      ),
    ];

    return SafeArea(
      top: false,
      child: Material(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.bellOff,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tắt thông báo',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chọn khoảng thời gian tắt thông báo',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: subtitleColor,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 4),

            // Danh sách lựa chọn
            ...options.map((opt) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    opt.icon,
                    size: 18,
                    color: opt.isDestructive
                        ? const Color(0xFFEF4444)
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                ),
                title: Text(
                  opt.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: opt.isDestructive
                        ? const Color(0xFFEF4444)
                        : textColor,
                  ),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, opt.minutes);
                },
              );
            }),
          ],
        ),
      ),
    ),
  );
  }
}

class _MuteOption {
  final String title;
  final int minutes;
  final IconData icon;
  final bool isDestructive;

  const _MuteOption({
    required this.title,
    required this.minutes,
    required this.icon,
    this.isDestructive = false,
  });
}
