import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/utils/local_attachment_cache.dart';
import '../../../shared/widgets/html_network_image.dart';
import '../application/messages_controller.dart';
import 'forward_conversation_sheet.dart';

/// Full-screen image viewer for a chat attachment. Supports pinch-zoom,
/// download (cross-platform), and forward (re-send the attachment into another
/// conversation).
///
/// [attachmentId] is the Odoo attachment id; null means the image was an inline
/// URL with no attachment record — download falls back to opening the URL and
/// forward is disabled (no bytes to re-upload).
class ImageViewerScreen extends ConsumerStatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.fileName,
    required this.attachmentId,
  });

  final String imageUrl;
  final String? fileName;
  final int? attachmentId;

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  bool _downloading = false;
  bool _forwarding = false;

  bool get _canForward => widget.attachmentId != null;

  Future<void> _download() async {
    if (_downloading) return;
    HapticFeedback.lightImpact();
    setState(() => _downloading = true);
    try {
      final id = widget.attachmentId;
      bool saved;
      if (id != null) {
        final bytes = await ref
            .read(downloadAttachmentActionProvider)
            .bytes(id.toString());
        if (!mounted) return;
        saved = await saveBytesToFile(
          bytes,
          widget.fileName ?? 'attachment_$id',
        );
      } else {
        // No attachment record: best-effort open in a new tab (web) / no-op.
        saved = openDownloadUrl(widget.imageUrl);
      }
      if (!mounted) return;
      _showSnack(
        saved
            ? 'Đã tải ${widget.fileName ?? 'tệp'}'
            : 'Đã huỷ tải xuống.',
      );
    } catch (e) {
      if (mounted) {
        _showSnack('Tải xuống thất bại: $e');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _forward() async {
    if (_forwarding || !_canForward) return;
    final id = widget.attachmentId!.toString();
    HapticFeedback.lightImpact();
    final target = await showForwardConversationPicker(context);
    if (target == null) return;
    setState(() => _forwarding = true);
    try {
      await ref
          .read(forwardAttachmentActionProvider)
          .forward(target.id, id);
      if (!mounted) return;
      _showSnack('Đã chuyển tiếp đến ${target.title}');
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        _showSnack('Chuyển tiếp thất bại: $e');
      }
    } finally {
      if (mounted) setState(() => _forwarding = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: _ViewerImage(
                  url: widget.imageUrl,
                  attachmentId: widget.attachmentId,
                  fileName: widget.fileName,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Row(
                  children: [
                    _ActionButton(
                      icon: LucideIcons.chevronLeft,
                      tooltip: 'Đóng',
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.fileName ?? 'Ảnh',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _ActionButton(
                      icon: LucideIcons.download,
                      tooltip: 'Tải xuống',
                      loading: _downloading,
                      onTap: _downloading ? null : _download,
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: LucideIcons.forward,
                      tooltip: _canForward
                          ? 'Chuyển tiếp'
                          : 'Không thể chuyển tiếp ảnh này',
                      loading: _forwarding,
                      onTap: (_forwarding || !_canForward) ? null : _forward,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _ViewerImage extends ConsumerWidget {
  const _ViewerImage({
    required this.url,
    required this.attachmentId,
    this.fileName,
  });

  final String url;
  final int? attachmentId;
  final String? fileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Local-First Architecture: Check local persistent attachment cache first (0ms)
    final localBytes = LocalAttachmentCache.get(
      attachmentId?.toString(),
      altKey: fileName ?? url,
    );

    if (localBytes != null && localBytes.isNotEmpty) {
      return Image.memory(
        localBytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _ViewerImageError(),
      );
    }

    final rawUrl = (attachmentId != null && attachmentId! > 0)
        ? '/api/v1/mobile/attachments/$attachmentId/download'
        : (url.trim().isNotEmpty ? url.trim() : '');

    final authUrl = odooApiClient.authenticatedUrl(rawUrl);

    if (kIsWeb) {
      final htmlImage = buildHtmlNetworkImage(url: authUrl, fit: BoxFit.contain);
      if (htmlImage != null) return htmlImage;
    }

    final id = attachmentId;
    if (id != null && id > 0) {
      return FutureBuilder<Uint8List>(
        future: ref.read(downloadAttachmentActionProvider).bytes(id.toString()),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null && bytes.isNotEmpty) {
            // Save to LocalAttachmentCache once loaded from server
            LocalAttachmentCache.save(id.toString(), bytes);
            if (fileName != null) LocalAttachmentCache.save(fileName!, bytes);
            return Image.memory(bytes, fit: BoxFit.contain);
          }
          if (snapshot.hasError) {
            return const _ViewerImageError();
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      );
    }

    return Image.network(
      authUrl,
      fit: BoxFit.contain,
      headers: odooApiClient.authHeaders,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: progress.cumulativeBytesLoaded /
                (progress.expectedTotalBytes ?? 1),
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (_, _, _) => const _ViewerImageError(),
    );
  }
}

class _ViewerImageError extends StatelessWidget {
  const _ViewerImageError();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.imageOff, color: Colors.white54, size: 40),
        SizedBox(height: 10),
        Text(
          'Không tải được ảnh.',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}
