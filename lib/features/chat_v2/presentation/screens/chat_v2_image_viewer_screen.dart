import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/gallery_saver.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../../../shared/widgets/html_network_image.dart';
import '../../data/models/chat_v2_message.dart';
import '../widgets/chat_v2_message_item.dart';

/// Đại diện cho 1 phần tử ảnh trong Gallery trình xem ảnh.
class ChatV2ImageItem {
  final String imageUrl;
  final String title;
  final Uint8List? bytes;
  final String? attachmentId;
  final String? heroTag;

  const ChatV2ImageItem({
    required this.imageUrl,
    this.title = 'Hình ảnh',
    this.bytes,
    this.attachmentId,
    this.heroTag,
  });
}

class ChatV2ImageViewerScreen extends StatefulWidget {
  final List<ChatV2Attachment>? images;
  final int initialIndex;
  final String? imageUrl;
  final String title;
  final Uint8List? bytes;
  final String? attachmentId;
  final String? heroTag;
  final Future<void> Function(Uint8List bytes, String fileName)? customShareHandler;

  const ChatV2ImageViewerScreen({
    super.key,
    this.images,
    this.initialIndex = 0,
    this.imageUrl,
    this.title = 'Hình ảnh',
    this.bytes,
    this.attachmentId,
    this.heroTag,
    this.customShareHandler,
  });

  /// Route mở ImageViewer với hiệu ứng Zoom/Hero và Fade mượt mà chuẩn Zalo/Telegram/Messenger,
  /// loại bỏ hoàn toàn hiệu ứng kéo trượt từ phải sang (slide from right).
  static Route<void> route({
    List<ChatV2Attachment>? images,
    int initialIndex = 0,
    String? imageUrl,
    String title = 'Hình ảnh',
    Uint8List? bytes,
    String? attachmentId,
    String? heroTag,
    Future<void> Function(Uint8List bytes, String fileName)? customShareHandler,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChatV2ImageViewerScreen(
          images: images,
          initialIndex: initialIndex,
          imageUrl: imageUrl,
          title: title,
          bytes: bytes,
          attachmentId: attachmentId,
          heroTag: heroTag,
          customShareHandler: customShareHandler,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        );
      },
    );
  }

  @override
  State<ChatV2ImageViewerScreen> createState() => _ChatV2ImageViewerScreenState();
}

class _ChatV2ImageViewerScreenState extends State<ChatV2ImageViewerScreen>
    with TickerProviderStateMixin {
  late List<ChatV2ImageItem> _items;
  late int _currentIndex;
  late PageController _pageController;

  final Map<int, Uint8List> _itemBytes = {};
  final Set<int> _loadingIndices = {};
  final Map<int, TransformationController> _transformationControllers = {};

  int _rotationTurns = 0;
  bool _isZoomed = false;
  bool _downloading = false;
  bool _sharing = false;
  bool _showControls = true;
  double _dragOffsetY = 0.0;
  double _dragScale = 1.0;

  late AnimationController _animationController;
  late AnimationController _dragResetController;
  Animation<Matrix4>? _zoomAnimation;
  Animation<double>? _dragOffsetAnimation;
  Animation<double>? _dragScaleAnimation;

  TransformationController _controllerFor(int index) {
    return _transformationControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.images != null && widget.images!.isNotEmpty) {
      _items = [];
      for (int i = 0; i < widget.images!.length; i++) {
        final att = widget.images![i];
        final fullUrl = att.resolveFullUrl(odooApiClient.absoluteUrl(''));
        final tag = (i == widget.initialIndex && widget.heroTag != null)
            ? widget.heroTag
            : 'chat_v2_gallery_${att.id.isNotEmpty ? att.id : i}_$i';
        _items.add(ChatV2ImageItem(
          imageUrl: fullUrl,
          title: att.name,
          bytes: att.bytes,
          attachmentId: att.id.isNotEmpty ? att.id : null,
          heroTag: tag,
        ));
      }
    } else {
      _items = [
        ChatV2ImageItem(
          imageUrl: widget.imageUrl ?? '',
          title: widget.title,
          bytes: widget.bytes,
          attachmentId: widget.attachmentId,
          heroTag: widget.heroTag,
        ),
      ];
    }

    _currentIndex = widget.initialIndex.clamp(0, _items.isEmpty ? 0 : _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_zoomAnimation != null) {
          final controller = _controllerFor(_currentIndex);
          controller.value = _zoomAnimation!.value;
          final newScale = controller.value.getMaxScaleOnAxis();
          final zoomed = newScale > 1.05;
          if (_isZoomed != zoomed) {
            setState(() => _isZoomed = zoomed);
          }
        }
      });

    _dragResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        setState(() {
          if (_dragOffsetAnimation != null) {
            _dragOffsetY = _dragOffsetAnimation!.value;
          }
          if (_dragScaleAnimation != null) {
            _dragScale = _dragScaleAnimation!.value;
          }
        });
      });

    _loadItemBytes(_currentIndex);
    if (_currentIndex > 0) _loadItemBytes(_currentIndex - 1);
    if (_currentIndex < _items.length - 1) _loadItemBytes(_currentIndex + 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _dragResetController.dispose();
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _pruneOffscreenBytes(int centerIndex) {
    if (_itemBytes.length <= 5) return;
    _itemBytes.removeWhere((idx, bytes) {
      if ((idx - centerIndex).abs() > 2) {
        final originalBytes = _items[idx].bytes;
        return originalBytes == null || originalBytes.isEmpty;
      }
      return false;
    });
  }

  Future<void> _loadItemBytes(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_itemBytes.containsKey(index) || _loadingIndices.contains(index)) return;

    final item = _items[index];
    if (item.bytes != null && item.bytes!.isNotEmpty) {
      if (mounted) {
        setState(() => _itemBytes[index] = item.bytes!);
      }
      return;
    }

    _loadingIndices.add(index);

    final key = (item.attachmentId != null && item.attachmentId!.isNotEmpty)
        ? 'att_${item.attachmentId!}'
        : (item.imageUrl.isNotEmpty ? 'url_${item.imageUrl}' : null);

    final cached = key != null
        ? (LocalAttachmentCache.get(key) ??
            ChatV2AttachmentImage.imageCache[key] ??
            ChatV2AttachmentImage.imageCache[item.attachmentId ?? ''])
        : null;

    if (cached != null && cached.isNotEmpty) {
      _loadingIndices.remove(index);
      if (mounted) {
        setState(() => _itemBytes[index] = cached);
      }
      return;
    }

    final attId = int.tryParse(item.attachmentId ?? '');
    if (attId != null) {
      try {
        final bytes = await MobileAttachmentRepository().fetchBytes(attId);
        if (bytes.isNotEmpty) {
          if (key != null) {
            LocalAttachmentCache.save(key, bytes);
            ChatV2AttachmentImage.cacheBytes(key, bytes);
          }
          _loadingIndices.remove(index);
          if (mounted) {
            setState(() => _itemBytes[index] = bytes);
          }
          return;
        }
      } catch (_) {}
    }

    _loadingIndices.remove(index);
    if (mounted) {
      setState(() {});
    }
  }

  String _getSuggestedFileName(ChatV2ImageItem item) {
    final t = item.title.trim();
    if (t.isNotEmpty &&
        (t.toLowerCase().endsWith('.png') ||
            t.toLowerCase().endsWith('.jpg') ||
            t.toLowerCase().endsWith('.jpeg') ||
            t.toLowerCase().endsWith('.webp') ||
            t.toLowerCase().endsWith('.gif'))) {
      return t;
    }
    final uri = Uri.tryParse(item.imageUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSeg = uri.pathSegments.last;
      if (lastSeg.contains('.') &&
          (lastSeg.toLowerCase().endsWith('.png') ||
              lastSeg.toLowerCase().endsWith('.jpg') ||
              lastSeg.toLowerCase().endsWith('.jpeg') ||
              lastSeg.toLowerCase().endsWith('.webp') ||
              lastSeg.toLowerCase().endsWith('.gif'))) {
        return lastSeg;
      }
    }
    final ext = item.imageUrl.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'vcloud_image_$timestamp.$ext';
  }

  Future<void> _downloadImage() async {
    if (_downloading || _items.isEmpty) return;
    final item = _items[_currentIndex];
    setState(() => _downloading = true);

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải ảnh...'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Uint8List? fileBytes = _itemBytes[_currentIndex] ?? item.bytes;

      // 1. Nếu chưa có bytes trong RAM, nạp qua MobileAttachmentRepository hoặc odooApiClient
      if (fileBytes == null || fileBytes.isEmpty) {
        final attId = int.tryParse(item.attachmentId ?? '');
        if (attId != null) {
          try {
            fileBytes = await MobileAttachmentRepository().fetchBytes(attId);
          } catch (_) {}
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        final cleanUrl = item.imageUrl.trim();
        if (cleanUrl.isNotEmpty &&
            (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'))) {
          try {
            fileBytes = await odooApiClient.fetchBytes(cleanUrl);
          } catch (_) {}
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Không tìm thấy dữ liệu ảnh để tải về');
      }

      final fileName = _getSuggestedFileName(item);
      final success = await GallerySaver.saveImage(
        bytes: fileBytes,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
              content: const Row(
                children: [
                  Icon(
                    LucideIcons.checkCircle2,
                    color: Color(0xFF22C55E),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đã lưu ảnh vào Thư viện',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể lưu ảnh vào Thư viện'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải ảnh: ${e.toString().replaceAll("Exception: ", "")}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  String _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _rotateImage() {
    setState(() {
      _rotationTurns = (_rotationTurns + 1) % 4;
    });
    final controller = _controllerFor(_currentIndex);
    if (controller.value != Matrix4.identity()) {
      controller.value = Matrix4.identity();
      if (_isZoomed) {
        setState(() => _isZoomed = false);
      }
    }
  }

  Future<void> _shareImage() async {
    if (_sharing || _items.isEmpty) return;
    final item = _items[_currentIndex];
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    setState(() => _sharing = true);

    try {
      Uint8List? fileBytes = _itemBytes[_currentIndex] ?? item.bytes;

      if (fileBytes == null || fileBytes.isEmpty) {
        final attId = int.tryParse(item.attachmentId ?? '');
        if (attId != null) {
          try {
            fileBytes = await MobileAttachmentRepository().fetchBytes(attId);
          } catch (_) {}
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        final cleanUrl = item.imageUrl.trim();
        if (cleanUrl.isNotEmpty &&
            (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'))) {
          try {
            fileBytes = await odooApiClient.fetchBytes(cleanUrl);
          } catch (_) {}
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy dữ liệu ảnh để chia sẻ'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final fileName = _getSuggestedFileName(item);

      if (widget.customShareHandler != null) {
        await widget.customShareHandler!(fileBytes, fileName);
        return;
      }

      final mimeType = _getMimeType(fileName);

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              fileBytes,
              name: fileName,
              mimeType: mimeType,
            ),
          ],
          text: 'Chia sẻ hình ảnh từ VCloud Chat',
          fileNameOverrides: [fileName],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chia sẻ ảnh: ${e.toString().replaceAll("Exception: ", "")}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  void _handleDoubleTap(int index, TapDownDetails? details) {
    final controller = _controllerFor(index);
    final currentMatrix = controller.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final Matrix4 endMatrix;
    if (currentScale > 1.05) {
      endMatrix = Matrix4.identity();
    } else {
      final position = details?.localPosition ?? Offset.zero;
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

  void _resetCurrentZoom() {
    final controller = _controllerFor(_currentIndex);
    if (controller.value != Matrix4.identity()) {
      controller.value = Matrix4.identity();
      if (_isZoomed) {
        setState(() => _isZoomed = false);
      }
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;

    if (_dragResetController.isAnimating) {
      _dragResetController.stop();
    }

    setState(() {
      _dragOffsetY += details.delta.dy;
      _dragScale = (1.0 - (_dragOffsetY.abs() / 1000)).clamp(0.8, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;

    if (_dragOffsetY.abs() > 80 || (details.primaryVelocity?.abs() ?? 0) > 500) {
      Navigator.of(context).pop();
    } else {
      _dragOffsetAnimation = Tween<double>(
        begin: _dragOffsetY,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _dragResetController,
        curve: Curves.easeOutCubic,
      ));
      _dragScaleAnimation = Tween<double>(
        begin: _dragScale,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _dragResetController,
        curve: Curves.easeOutCubic,
      ));
      _dragResetController.forward(from: 0.0);
    }
  }

  /// Kiểm tra có hiển thị tiêu đề trên thanh header hay không.
  /// Ẩn hoàn toàn nếu rỗng hoặc là tên file ảnh kỹ thuật (image_picker_..., scaled_..., raw filename).
  bool _shouldShowTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return false;
    final lower = t.toLowerCase();
    if (lower.startsWith('image_picker') ||
        lower.startsWith('scaled_') ||
        lower.contains('image_picker')) {
      return false;
    }
    // Ẩn nếu là tên file ảnh thô (không có khoảng trắng, có phần mở rộng ảnh)
    final isRawFilename = !t.contains(' ') &&
        (lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.gif') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.heic') ||
            lower.endsWith('.heif') ||
            lower.endsWith('.bmp'));
    if (isRawFilename) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive image container with PageView & Gestures
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Transform.scale(
                scale: _dragScale,
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: _items.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _rotationTurns = 0;
                      _isZoomed = false;
                      _dragOffsetY = 0.0;
                      _dragScale = 1.0;
                    });
                    _loadItemBytes(index);
                    if (index > 0) _loadItemBytes(index - 1);
                    if (index < _items.length - 1) _loadItemBytes(index + 1);
                    _pruneOffscreenBytes(index);

                    for (final entry in _transformationControllers.entries) {
                      if (entry.key != index && entry.value.value != Matrix4.identity()) {
                        entry.value.value = Matrix4.identity();
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    final controller = _controllerFor(index);
                    TapDownDetails? pageTapDownDetails;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _showControls = !_showControls;
                        });
                      },
                      onDoubleTapDown: (details) => pageTapDownDetails = details,
                      onDoubleTap: () => _handleDoubleTap(index, pageTapDownDetails),
                      child: InteractiveViewer(
                        transformationController: controller,
                        minScale: 0.8,
                        maxScale: 6.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        clipBehavior: Clip.none,
                        onInteractionUpdate: (details) {
                          final scale = controller.value.getMaxScaleOnAxis();
                          final zoomed = scale > 1.05;
                          if (_isZoomed != zoomed) {
                            setState(() => _isZoomed = zoomed);
                          }
                        },
                        onInteractionEnd: (details) {
                          final scale = controller.value.getMaxScaleOnAxis();
                          final zoomed = scale > 1.05;
                          if (_isZoomed != zoomed) {
                            setState(() => _isZoomed = zoomed);
                          }
                        },
                        child: SizedBox.expand(
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: index == _currentIndex ? _rotationTurns : 0,
                              child: _buildImageContent(index),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
                  if (_items.length > 1) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_currentIndex + 1} / ${_items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ] else if (_shouldShowTitle(_items.first.title)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _items.first.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.rotateCw, color: Colors.white, size: 20),
                    tooltip: 'Xoay ảnh 90°',
                    onPressed: _rotateImage,
                  ),
                  IconButton(
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share, color: Colors.white, size: 20),
                    tooltip: 'Chia sẻ ảnh',
                    onPressed: _sharing ? null : _shareImage,
                  ),
                  IconButton(
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.download, color: Colors.white, size: 20),
                    tooltip: 'Tải ảnh về máy',
                    onPressed: _downloading ? null : _downloadImage,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.rotateCcw, color: Colors.white, size: 20),
                    tooltip: 'Đặt lại thu phóng',
                    onPressed: _resetCurrentZoom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(int index) {
    final item = _items[index];
    final bytes = _itemBytes[index] ?? item.bytes;
    final isLoading = _loadingIndices.contains(index);

    final Widget content;
    if (bytes != null && bytes.isNotEmpty) {
      content = Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildNetworkOrError(item),
      );
    } else if (isLoading) {
      content = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else {
      content = _buildNetworkOrError(item);
    }

    if (item.heroTag != null && item.heroTag!.isNotEmpty) {
      return Hero(
        tag: item.heroTag!,
        child: content,
      );
    }
    return content;
  }

  Widget _buildNetworkOrError(ChatV2ImageItem item) {
    final cleanUrl = item.imageUrl.trim();
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.imageOff, color: Colors.white54, size: 52),
            SizedBox(height: 14),
            Text(
              'Hình ảnh rỗng hoặc không còn tồn tại trên máy chủ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
