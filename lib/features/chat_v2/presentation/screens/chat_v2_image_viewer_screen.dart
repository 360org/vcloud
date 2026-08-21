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

class _ChatV2ImageViewerScreenState extends State<ChatV2ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _bytes;
  bool _loading = true;
  bool _showControls = true;
  double _dragOffsetY = 0.0;
  double _dragScale = 1.0;

  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });
    _loadBytes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
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

    final key = (widget.attachmentId != null && widget.attachmentId!.isNotEmpty)
        ? 'att_${widget.attachmentId!}'
        : (widget.imageUrl.isNotEmpty ? 'url_${widget.imageUrl}' : null);

    final cached = key != null
        ? (LocalAttachmentCache.get(key) ??
            ChatV2AttachmentImage.imageCache[key] ??
            ChatV2AttachmentImage.imageCache[widget.attachmentId ?? ''])
        : null;

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
          if (key != null) {
            LocalAttachmentCache.save(key, bytes);
            ChatV2AttachmentImage.cacheBytes(key, bytes);
          }
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

  void _handleDoubleTap() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final Matrix4 endMatrix;
    if (currentScale > 1.05) {
      endMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      endMatrix = Matrix4.identity()
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
    }

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: endMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward(from: 0);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) return;

    setState(() {
      _dragOffsetY += details.delta.dy;
      _dragScale = (1.0 - (_dragOffsetY.abs() / 1000)).clamp(0.8, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) return;

    if (_dragOffsetY.abs() > 90 || (details.primaryVelocity?.abs() ?? 0) > 600) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffsetY = 0.0;
        _dragScale = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = (1.0 - (_dragOffsetY.abs() / 400)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive image container with Gestures
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            onDoubleTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: _handleDoubleTap,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Transform.scale(
                scale: _dragScale,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 6.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  clipBehavior: Clip.none,
                  child: SizedBox.expand(
                    child: Center(
                      child: _buildImageContent(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating Top Header
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.rotateCcw, color: Colors.white, size: 20),
                    tooltip: 'Đặt lại thu phóng',
                    onPressed: () {
                      _transformationController.value = Matrix4.identity();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
