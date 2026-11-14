import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../data/services/link_metadata_service.dart';

/// Card xem trước liên kết phong phú (Rich Link Preview) trong Chat V2.
/// Tự động hiển thị thumbnail, tên miền, tiêu đề và mô tả.
/// Thiết kế chuẩn Refined Tech Luxury, hỗ trợ bấm mở trình duyệt và nhấn giữ để sao chép.
class LinkPreviewCard extends ConsumerWidget {
  const LinkPreviewCard({
    super.key,
    required this.url,
    this.isMine = false,
  });

  final String url;
  final bool isMine;

  static void openUrl(BuildContext context, String targetUrl) async {
    HapticFeedback.lightImpact();
    final cleanUrl = targetUrl.trim();
    final uri = Uri.tryParse(
      cleanUrl.contains('://') ? cleanUrl : 'https://$cleanUrl',
    );
    if (uri == null) return;

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[LinkPreviewCard] Error opening URL: $e');
      await Clipboard.setData(ClipboardData(text: targetUrl));
      if (context.mounted) {
        AppToast.info(context, title: 'Đã sao chép liên kết vào bộ nhớ tạm');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadataAsync = ref.watch(linkMetadataProvider(url));

    return metadataAsync.when(
      data: (metadata) {
        if (metadata == null || !metadata.hasContent) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final hasImage = metadata.imageUrl != null && metadata.imageUrl!.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => openUrl(context, metadata.url),
              onLongPress: () async {
                HapticFeedback.mediumImpact();
                await Clipboard.setData(ClipboardData(text: metadata.url));
                if (context.mounted) {
                  AppToast.success(context, title: 'Đã sao chép liên kết');
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ảnh thumbnail (nếu có)
                    if (hasImage)
                      SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              metadata.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) {
                                return _buildImagePlaceholder(isDark);
                              },
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return _buildImageLoading(isDark);
                              },
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.globe,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      metadata.domain,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Nội dung text chi tiết
                    Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Domain chip khi không có ảnh banner
                          if (!hasImage)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.globe,
                                    size: 12,
                                    color: isDark
                                        ? const Color(0xFF60A5FA)
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      metadata.domain,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFF93C5FD)
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Tiêu đề
                          if (metadata.title?.isNotEmpty == true)
                            Text(
                              metadata.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),

                          // Mô tả
                          if (metadata.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              metadata.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          LucideIcons.globe,
          size: 28,
          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildImageLoading(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
