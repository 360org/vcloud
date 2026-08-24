import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key});

  static const String _storageKey = 'whats_new_seen_build_number';

  /// Kiểm tra và tự động hiển thị Sheet nếu người dùng chưa xem build [targetBuild]
  static Future<void> showIfNeeded(BuildContext context, {int targetBuild = 84}) async {
    try {
      const storage = FlutterSecureStorage();
      final seenStr = await storage.read(key: _storageKey);
      final seenBuild = int.tryParse(seenStr ?? '') ?? 0;

      if (seenBuild < targetBuild) {
        if (!context.mounted) return;
        await show(context);
        await storage.write(key: _storageKey, value: targetBuild.toString());
      }
    } catch (_) {
      // Bỏ qua lỗi storage để không làm gián đoạn trải nghiệm
    }
  }

  /// Hiển thị Modal BottomSheet trực tiếp
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WhatsNewSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final maxHeight = size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh kéo (Drag handle)
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Badge phiên bản gradient
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF00C83A).withValues(alpha: 0.25), const Color(0xFF0284C7).withValues(alpha: 0.25)]
                            : [const Color(0xFFE7FBEA), const Color(0xFFEFF6FF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00C83A).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF00C83A)),
                        SizedBox(width: 6),
                        Text(
                          'PHIÊN BẢN MỚI v2.5.0 (BUILD 84)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00C83A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tiêu đề chính
                  Text(
                    'Trò Chuyện Trực Tiếp & Cảm Xúc Sống Động',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Phụ đề
                  Text(
                    'Khám phá tính năng Ghi âm thoại, chi tiết thả cảm xúc (Reaction), thông báo nổi In-App và tối ưu tải nhóm chat siêu tốc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Danh sách các thẻ tính năng (Cuộn mượt mà)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FeatureCard(
                    icon: LucideIcons.mic,
                    iconColor: const Color(0xFF00C83A),
                    tagText: 'TÍNH NĂNG MỚI',
                    tagColor: const Color(0xFF00C83A),
                    title: 'Ghi Âm & Tin Nhắn Thoại',
                    description: 'Gửi tin nhắn thoại chất lượng cao trực tiếp trong luồng chat. Trải nghiệm giao tiếp nhanh chóng và sinh động hơn.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _FeatureCard(
                    icon: LucideIcons.smilePlus,
                    iconColor: const Color(0xFF0284C7),
                    tagText: 'TRẢI NGHIỆM',
                    tagColor: const Color(0xFF0284C7),
                    title: 'Chi Tiết Thả Cảm Xúc (Reactions)',
                    description: 'Nhấn giữ tin nhắn để thả cảm xúc, nhấn vào emoji để xem chi tiết ai đã thả biểu tượng gì một cách trực quan.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _FeatureCard(
                    icon: LucideIcons.bellRing,
                    iconColor: const Color(0xFFEA580C),
                    tagText: 'THÔNG BÁO',
                    tagColor: const Color(0xFFEA580C),
                    title: 'Thông Báo Nổi In-App (Banner)',
                    description: 'Nhận ngay thông báo tin nhắn mới dạng banner nổi (Floating) khi đang sử dụng app, không lo bỏ lỡ thông tin.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _FeatureCard(
                    icon: LucideIcons.zap,
                    iconColor: const Color(0xFF7C3AED),
                    tagText: 'HIỆU NĂNG',
                    tagColor: const Color(0xFF7C3AED),
                    title: 'Tải Nhóm Chat Siêu Tốc & Fix Lỗi',
                    description: 'Tối ưu API tải danh sách thành viên nhóm nhanh gấp 5 lần, đồng thời khắc phục triệt để lỗi mất ảnh (hiện text) khi F5.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Nút CTA Khám phá ngay
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C83A), Color(0xFF009D2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C83A).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.rocket, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'KHÁM PHÁ & TRẢI NGHIỆM NGAY',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.tagText,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String tagText;
  final Color tagColor;
  final String title;
  final String description;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2A4A).withValues(alpha: 0.6)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon tròn với soft background
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Nội dung thẻ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tagText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: tagColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
