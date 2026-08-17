import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../../../shared/widgets/html_network_image.dart';
import '../widgets/chat_v2_message_item.dart';

class ChatV2ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String title;
  final Uint8List? bytes;
  final String? attachmentId;

  const ChatV2ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.title = 'Hình ảnh',
    this.bytes,
    this.attachmentId,
  });

  @override
  State<ChatV2ImageViewerScreen> createState() => _ChatV2ImageViewerScreenState();
}

class _ChatV2ImageViewerScreenState extends State<ChatV2ImageViewerScreen> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  Future<void> _loadBytes() async {
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _bytes = widget.bytes;
          _loading = false;
        });
      }
      return;
    }

    final cached = LocalAttachmentCache.get(
          widget.attachmentId,
          altKey: widget.title,
        ) ??
        (widget.attachmentId != null ? ChatV2AttachmentImage.imageCache[widget.attachmentId!] : null) ??
        ChatV2AttachmentImage.imageCache[widget.title];

    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _bytes = cached;
          _loading = false;
        });
      }
      return;
    }

    final attId = int.tryParse(widget.attachmentId ?? '');
    if (attId != null) {
      try {
        final bytes = await MobileAttachmentRepository().fetchBytes(attId);
        if (bytes.isNotEmpty) {
          LocalAttachmentCache.save(widget.attachmentId!, bytes);
          LocalAttachmentCache.save(widget.title, bytes);
          if (mounted) {
            setState(() {
              _bytes = bytes;
              _loading = false;
            });
          }
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildNetworkOrError(),
      );
    }

    return _buildNetworkOrError();
  }

  Widget _buildNetworkOrError() {
    final cleanUrl = widget.imageUrl.trim();
    if (cleanUrl.isNotEmpty && (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'))) {
      if (kIsWeb) {
        final htmlImg = buildHtmlNetworkImage(url: cleanUrl, fit: BoxFit.contain);
        if (htmlImg != null) return htmlImg;
      }
      return Image.network(
        cleanUrl,
        fit: BoxFit.contain,
        headers: odooApiClient.authHeaders,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildError(),
      );
    }
    return _buildError();
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
          SizedBox(height: 12),
          Text(
            'Không thể tải hình ảnh',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
